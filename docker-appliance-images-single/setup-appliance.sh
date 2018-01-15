#!/bin/sh

set -a
set -e
set -u

. ${APPLIANCE_FOLDER}/build/scripts/env-vars.sh

RAND_SRV_PORT=16000

MYSQL_SQL_ADDRESS=$(getent hosts epics-archiver-mysql-db | awk '{ print $1 }')

RETRIEVAL_DEFAULT_PORT=31998

sed -i 's/username=.*$/username=\"'"${MYSQL_USER}"'\"/' ${CATALINA_HOME}/conf/context.xml
sed -i 's/password=.*$/password=\"'"${MYSQL_PASSWORD}"'\"/' ${CATALINA_HOME}/conf/context.xml
sed -i 's/url=.*$/url=\"jdbc:mysql:\/\/'"${MYSQL_SQL_ADDRESS}"':'"${MYSQL_PORT}"'\/'"${MYSQL_DATABASE}"'\"/' ${CATALINA_HOME}/conf/context.xml

# Before starting Tomcat service, change all addresses in lnls_appliances.xml.
# Get local ip address
IP_ADDRESS=$(ip addr show eth0 | grep "inet\b" | awk '{print $2}' | cut -d/ -f1)

# Generates keystore
keytool -genkey -alias tomcat -keyalg RSA -dname "CN=${IP_ADDRESS}, OU=Controls Group, O=LNLS, L=Campinas, ST=Sao Paulo, C=BR" -storepass ${CERTIFICATE_PASSWORD} -keypass ${CERTIFICATE_PASSWORD} -keystore ${APPLIANCE_FOLDER}/build/cert/appliance-mgmt.keystore
# Copies keystore to conf/
cp ${APPLIANCE_FOLDER}/build/cert/appliance-mgmt.keystore conf/
# Generates certificate
keytool -exportcert -keystore conf/appliance-mgmt.keystore -alias tomcat -storepass ${CERTIFICATE_PASSWORD} -file ${APPLIANCE_FOLDER}/build/cert/archiver-mgmt.crt
# Imports certificate into trusted keystore
keytool -import -alias tomcat -trustcacerts -storepass ${CERTIFICATE_PASSWORD} -noprompt -keystore $JAVA_HOME/lib/security/cacerts -file ${APPLIANCE_FOLDER}/build/cert/archiver-mgmt.crt

for APPLIANCE_UNIT in "mgmt" "engine" "retrieval" "etl"
do

    APPLIANCE_PORT=$(xmlstarlet sel -t -v "/appliances/appliance[identity='${ARCHAPPL_MYIDENTITY}']/${APPLIANCE_UNIT}_url" ${ARCHAPPL_APPLIANCES} | sed "s/.*://" | sed "s/\/.*//" ) 

    mkdir -p ${CATALINA_HOME}/${APPLIANCE_UNIT}
    cp -r ${CATALINA_HOME}/conf ${CATALINA_HOME}/${APPLIANCE_UNIT}/conf
    cp -r ${CATALINA_HOME}/webapps ${CATALINA_HOME}/${APPLIANCE_UNIT}/webapps
    mkdir -p ${CATALINA_HOME}/${APPLIANCE_UNIT}/logs
    mkdir -p ${CATALINA_HOME}/${APPLIANCE_UNIT}/temp
    mkdir -p ${CATALINA_HOME}/${APPLIANCE_UNIT}/work

    xmlstarlet ed -L -u '/Server/@port' -v ${RAND_SRV_PORT} ${CATALINA_HOME}/${APPLIANCE_UNIT}/conf/server.xml

    if [ "${APPLIANCE_UNIT}" = "engine" ] || [ "${APPLIANCE_UNIT}" = "etl" ] || [ "${APPLIANCE_UNIT}" = "retrieval" ]; then

            xmlstarlet ed -L -u "/appliances/appliance[identity='${ARCHAPPL_MYIDENTITY}']/${APPLIANCE_UNIT}_url" -v "http://${IP_ADDRESS}:${APPLIANCE_PORT}/${APPLIANCE_UNIT}/bpl" ${ARCHAPPL_APPLIANCES}

            if [ "${APPLIANCE_UNIT}" = "retrieval" ]; then
                   xmlstarlet ed -L -u "/appliances/appliance[identity='${ARCHAPPL_MYIDENTITY}']/data_retrieval_url" -v "http://${IP_ADDRESS}:${APPLIANCE_PORT}/${APPLIANCE_UNIT}" ${ARCHAPPL_APPLIANCES}
            fi

            # Appends new connector
            xmlstarlet ed -L -u "/Server/Service/Connector[@protocol='HTTP/1.1']/@port" -v ${APPLIANCE_PORT} ${CATALINA_HOME}/${APPLIANCE_UNIT}/conf/server.xml

            # Remove every other connector entry from the conf/server.xml
            xmlstarlet ed -L -d "/Server/Service/Connector[@protocol!='HTTP/1.1']" ${CATALINA_HOME}/${APPLIANCE_UNIT}/conf/server.xml

    elif [ "${APPLIANCE_UNIT}" = "mgmt" ]; then

            # Sets cluster inet port
            xmlstarlet ed -L -u "/appliances/appliance[identity='${ARCHAPPL_MYIDENTITY}']/cluster_inetport" -v "${IP_ADDRESS}:12000" ${ARCHAPPL_APPLIANCES}

            xmlstarlet ed -L -u "/appliances/appliance[identity='${ARCHAPPL_MYIDENTITY}']/${APPLIANCE_UNIT}_url" -v "https://${IP_ADDRESS}:${APPLIANCE_PORT}/${APPLIANCE_UNIT}/bpl" ${ARCHAPPL_APPLIANCES}

            # Remove default connector port
            xmlstarlet ed -L -d "/Server/Service/Connector" ${CATALINA_HOME}/${APPLIANCE_UNIT}/conf/server.xml

            # Appends new connector
            xmlstarlet ed -L -s "/Server/Service" -t elem -n "Connector" \
                             -i "/Server/Service/Connector" -t attr -n "protocol" -v "org.apache.coyote.http11.Http11NioProtocol" \
                             -i "/Server/Service/Connector" -t attr -n "port" -v "${APPLIANCE_PORT}" \
                             -i "/Server/Service/Connector" -t attr -n "redirectPort" -v "8443" \
                             -i "/Server/Service/Connector" -t attr -n "maxThreads" -v "150" \
                             -i "/Server/Service/Connector" -t attr -n "SSLEnabled" -v "true" \
                             -i "/Server/Service/Connector" -t attr -n "scheme" -v "https" \
                             -i "/Server/Service/Connector" -t attr -n "secure" -v "true" \
                             ${CATALINA_HOME}/${APPLIANCE_UNIT}/conf/server.xml

            xmlstarlet ed -L -s '/Server/Service/Connector[@port='"${APPLIANCE_PORT}"']' -t elem -n "SSLHostConfig" ${CATALINA_HOME}/${APPLIANCE_UNIT}/conf/server.xml

            xmlstarlet ed -L -s '/Server/Service/Connector[@port='"${APPLIANCE_PORT}"']/SSLHostConfig' -t elem -n "Certificate" \
                             -i '/Server/Service/Connector[@port='"${APPLIANCE_PORT}"']/SSLHostConfig/Certificate' -t attr -n "certificateKeystoreFile" -v "conf/appliance-mgmt.keystore" \
                             -i '/Server/Service/Connector[@port='"${APPLIANCE_PORT}"']/SSLHostConfig/Certificate' -t attr -n "type" -v "RSA" \
                             ${CATALINA_HOME}/${APPLIANCE_UNIT}/conf/server.xml

            # Appends new realm
            xmlstarlet ed -L -s '/Server/Service/Engine/Host' -t elem -n "Realm" \
                             -i '/Server/Service/Engine/Host/Realm' -t attr -n "connectionURL" -v "ldap://ad1.abtlus.org.br:389" \
                             -i '/Server/Service/Engine/Host/Realm' -t attr -n "alternativeURL" -v "ldap://ad2.abtlus.org.br:389" \
                             -i '/Server/Service/Engine/Host/Realm' -t attr -n "userSearch" -v "(sAMAccountName={0})" \
                             -i '/Server/Service/Engine/Host/Realm' -t attr -n "userSubtree" -v "true" \
                             -i '/Server/Service/Engine/Host/Realm' -t attr -n "userBase" -v "OU=LNLS,DC=abtlus,DC=org,DC=br" \
                             -i '/Server/Service/Engine/Host/Realm' -t attr -n "connectionName" -v "${CONNECTION_NAME}" \
                             -i '/Server/Service/Engine/Host/Realm' -t attr -n "connectionPassword" -v "${CONNECTION_PASSWORD}" \
                             -i '/Server/Service/Engine/Host/Realm' -t attr -n "className" -v "org.apache.catalina.realm.JNDIRealm" \
                             ${CATALINA_HOME}/${APPLIANCE_UNIT}/conf/server.xml

	    # Changes viewer's url port
	    RETRIEVAL_PORT=$(xmlstarlet sel -t -v "/appliances/appliance[identity='${ARCHAPPL_MYIDENTITY}']/retrieval_url" ${ARCHAPPL_APPLIANCES} | sed "s/.*://" | sed "s/\/.*//" ) 
	    sed -i "s:${RETRIEVAL_DEFAULT_PORT}/retrieval:${RETRIEVAL_PORT}/retrieval:" ${GITHUB_REPOSITORY_FOLDER}/src/main/org/epics/archiverappliance/mgmt/staticcontent/js/mgmt.js
    fi

    # Change wardest and dist properties in build.xml to ./
    xmlstarlet ed -L -u "/project/property[@name='wardest']/@location" -v "./" ${GITHUB_REPOSITORY_FOLDER}/build.xml
    xmlstarlet ed -L -u "/project/property[@name='dist']/@location" -v "./" ${GITHUB_REPOSITORY_FOLDER}/build.xml

    # Build only specific war file
    export TOMCAT_HOME=${CATALINA_HOME}
    (cd ${GITHUB_REPOSITORY_FOLDER}; ant ${APPLIANCE_UNIT}_war)

    mkdir ${CATALINA_HOME}/${APPLIANCE_UNIT}/webapps/${APPLIANCE_UNIT}

    mv ${GITHUB_REPOSITORY_FOLDER}/${APPLIANCE_UNIT}.war ${CATALINA_HOME}/${APPLIANCE_UNIT}/webapps/${APPLIANCE_UNIT}
    (cd ${CATALINA_HOME}/${APPLIANCE_UNIT}/webapps/${APPLIANCE_UNIT}; jar xf ${APPLIANCE_UNIT}.war)

    rm ${CATALINA_HOME}/${APPLIANCE_UNIT}/webapps/${APPLIANCE_UNIT}/${APPLIANCE_UNIT}.war

    # Do not allow external accesses in engine and etl appliances
    if [ "${APPLIANCE_UNIT}" = "engine" ] || [ "${APPLIANCE_UNIT}" = "etl" ] ; then

	    echo "Applying access restriction from external networks..."
	    # Find a way to change allowed addresses with the internal network address
	    # xmlstarlet ed -L -s '/Context' -t elem -n 'Valve' \
	    #		  -i '/Context/Valve' -t attr -n 'className' -v 'org.apache.catalina.valves.RemoteAddrValve' \
	    #                 -i '/Context/Valve' -t attr -n 'allow' -v '172\.17\.\d+\.\d+' \
	    #                 ${CATALINA_HOME}/${APPLIANCE_UNIT}/conf/context.xml
    fi

    if [ "${APPLIANCE_UNIT}" = "retrieval" ]; then
            git clone https://github.com/gciotto/archiver-viewer.git ${CATALINA_HOME}/${APPLIANCE_UNIT}/webapps/${APPLIANCE_UNIT}/ui/archiver-viewer
            git clone https://github.com/slacmshankar/svg_viewer.git ${CATALINA_HOME}/${APPLIANCE_UNIT}/webapps/${APPLIANCE_UNIT}/ui/viewer
    fi

    RAND_SRV_PORT=$((RAND_SRV_PORT+1))

done
