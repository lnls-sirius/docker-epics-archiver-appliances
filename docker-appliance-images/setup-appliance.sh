#!/bin/sh

set -a
set -e
set -u

RAND_SRV_PORT=16000
MYSQL_SQL_ADDRESS=192.168.5.3

RETRIEVAL_DEFAULT_PORT=31998

APPLIANCE_PORT=$(xmlstarlet sel -t -v "/appliances/appliance[identity='${ARCHAPPL_MYIDENTITY}']/${APPLIANCE_UNIT}_url" ${ARCHAPPL_APPLIANCES} | sed "s/.*://" | sed "s/\/.*//" )

if [ "${USE_AUTHENTICATION}" = true ]; then
        GITHUB_APPLIANCES_BRANCH=${GITHUB_APPLIANCES_BRANCH:-ldap-login}
else
        GITHUB_APPLIANCES_BRANCH=${GITHUB_APPLIANCES_BRANCH:-master}
fi

(cd ${GITHUB_REPOSITORY_FOLDER}; git config user.email "controle@lnls.br"; git config user.name "Controls Group"; git fetch origin ${GITHUB_APPLIANCES_BRANCH}; git checkout ${GITHUB_APPLIANCES_BRANCH})

# Before starting Tomcat service, change all addresses in lnls_appliances.xml.
# Get local ip address
# IP_ADDRESS=$(ip addr show eth0 | grep "inet\b" | awk '{print $2}' | cut -d/ -f1)
IP_ADDRESS=$(hostname)

xmlstarlet ed -L -u '/Server/@port' -v ${RAND_SRV_PORT} ${CATALINA_HOME}/conf/server.xml

if [ "${APPLIANCE_UNIT}" = "engine" ] || [ "${APPLIANCE_UNIT}" = "etl" ] || [ "${APPLIANCE_UNIT}" = "retrieval" ]; then

        xmlstarlet ed -L -u "/Server/Service/Connector[@protocol='HTTP/1.1']/@port" -v ${APPLIANCE_PORT} ${CATALINA_HOME}/conf/server.xml
        # Remove every other connector entry from the conf/server.xml
        xmlstarlet ed -L -d "/Server/Service/Connector[@protocol!='HTTP/1.1']" ${CATALINA_HOME}/conf/server.xml

elif [ "${APPLIANCE_UNIT}" = "mgmt" ]; then

        if [ "${USE_AUTHENTICATION}" = true ]; then

            # Copies keystore to conf/
            cp ${APPLIANCE_FOLDER}/build/cert/appliance-mgmt.keystore conf/

            # Remove default connector port
            xmlstarlet ed -L -d "/Server/Service/Connector" ${CATALINA_HOME}/conf/server.xml

            # Appends new connector
            xmlstarlet ed -L -s "/Server/Service" -t elem -n "Connector" \
                             -i "/Server/Service/Connector" -t attr -n "protocol" -v "org.apache.coyote.http11.Http11NioProtocol" \
                             -i "/Server/Service/Connector" -t attr -n "port" -v "${APPLIANCE_PORT}" \
                             -i "/Server/Service/Connector" -t attr -n "redirectPort" -v "8443" \
                             -i "/Server/Service/Connector" -t attr -n "maxThreads" -v "150" \
                             -i "/Server/Service/Connector" -t attr -n "SSLEnabled" -v "true" \
                             -i "/Server/Service/Connector" -t attr -n "scheme" -v "https" \
                             -i "/Server/Service/Connector" -t attr -n "secure" -v "true" \
                             ${CATALINA_HOME}/conf/server.xml

            xmlstarlet ed -L -s '/Server/Service/Connector[@port='"${APPLIANCE_PORT}"']' -t elem -n "SSLHostConfig" ${CATALINA_HOME}/conf/server.xml

            xmlstarlet ed -L -s '/Server/Service/Connector[@port='"${APPLIANCE_PORT}"']/SSLHostConfig' -t elem -n "Certificate" \
                             -i '/Server/Service/Connector[@port='"${APPLIANCE_PORT}"']/SSLHostConfig/Certificate' -t attr -n "certificateKeystoreFile" -v "conf/appliance-mgmt.keystore" \
                             -i '/Server/Service/Connector[@port='"${APPLIANCE_PORT}"']/SSLHostConfig/Certificate' -t attr -n "type" -v "RSA" \
                             ${CATALINA_HOME}/conf/server.xml

            # Appends new realm
            xmlstarlet ed -L -s '/Server/Service/Engine/Host' -t elem -n "Realm" \
                             -i '/Server/Service/Engine/Host/Realm' -t attr -n "connectionURL" -v "${CONNECTION_URL}" \
                             -i '/Server/Service/Engine/Host/Realm' -t attr -n "userSearch" -v "${CONNECTION_USER_FILTER}" \
                             -i '/Server/Service/Engine/Host/Realm' -t attr -n "userSubtree" -v "true" \
                             -i '/Server/Service/Engine/Host/Realm' -t attr -n "userBase" -v "${CONNECTION_USER_BASE}" \
                             -i '/Server/Service/Engine/Host/Realm' -t attr -n "className" -v "org.apache.catalina.realm.JNDIRealm" \
                             ${CATALINA_HOME}/${APPLIANCE_UNIT}/conf/server.xml

           if [ ! -z ${ALTERNATIVE_URL+x} ]; then
                 xmlstarlet ed -L -i '/Server/Service/Engine/Host/Realm' -t attr -n "alternativeURL" -v "${ALTERNATIVE_URL}" \
                                   ${CATALINA_HOME}/${APPLIANCE_UNIT}/conf/server.xml
           fi

           if [ ! -z ${CONNECTION_ROLE_BASE+x} ]; then
                 xmlstarlet ed -L -i '/Server/Service/Engine/Host/Realm' -t attr -n "roleBase" -v "${CONNECTION_ROLE_BASE}" \
                                  -i '/Server/Service/Engine/Host/Realm' -t attr -n "roleSubtree" -v "true" \
                                   ${CATALINA_HOME}/${APPLIANCE_UNIT}/conf/server.xml
           fi

           if [ ! -z ${CONNECTION_ROLE_NAME+x} ]; then
                 xmlstarlet ed -L -i '/Server/Service/Engine/Host/Realm' -t attr -n "roleName" -v "${CONNECTION_ROLE_NAME}" ${CATALINA_HOME}/${APPLIANCE_UNIT}/conf/server.xml
           fi

           if [ ! -z ${CONNECTION_ROLE_SEARCH+x} ]; then
                 xmlstarlet ed -L -i '/Server/Service/Engine/Host/Realm' -t attr -n "roleSearch" -v "${CONNECTION_ROLE_SEARCH}" ${CATALINA_HOME}/${APPLIANCE_UNIT}/conf/server.xml
           fi


           if [ ! -z ${CONNECTION_NAME+x} ]; then
                 xmlstarlet ed -L -i '/Server/Service/Engine/Host/Realm' -t attr -n "connectionName" -v "${CONNECTION_NAME}" ${CATALINA_HOME}/${APPLIANCE_UNIT}/conf/server.xml
           fi

           if [ ! -z ${CONNECTION_PASSWORD+x} ]; then
                 xmlstarlet ed -L -i '/Server/Service/Engine/Host/Realm' -t attr -n "connectionPassword" -v "${CONNECTION_PASSWORD}" ${CATALINA_HOME}/${APPLIANCE_UNIT}/conf/server.xml
           fi

        else

            # Removes https from appliances xml file
            sed -i "s:https:http:g" ${ARCHAPPL_APPLIANCES}

            # Appends new connector
            xmlstarlet ed -L -u "/Server/Service/Connector[@protocol='HTTP/1.1']/@port" -v ${APPLIANCE_PORT} ${CATALINA_HOME}/conf/server.xml

            # Remove every other connector entry from the conf/server.xml
            xmlstarlet ed -L -d "/Server/Service/Connector[@protocol!='HTTP/1.1']" ${CATALINA_HOME}/conf/server.xml

        fi

    # Changes viewer's url port
    RETRIEVAL_PORT=$(xmlstarlet sel -t -v "/appliances/appliance[identity='${ARCHAPPL_MYIDENTITY}']/retrieval_url" ${ARCHAPPL_APPLIANCES} | sed "s/.*://" | sed "s/\/.*//" )
    sed -i 's#var dataRetrievalURL = .*$#var dataRetrievalURL = window.location.port != "" \&\& window.location.port > 0 ? "http:" + window.location.href.split(":")[1] + ":'"${RETRIEVAL_PORT}"'/retrieval" :  "http://" + window.location.hostname + "/retrieval";#g' ${GITHUB_REPOSITORY_FOLDER}/src/main/org/epics/archiverappliance/mgmt/staticcontent/js/mgmt.js

fi

# Imports certificate into trusted keystore
keytool -import -alias tomcat -trustcacerts -storepass ${CERTIFICATE_PASSWORD} -noprompt -keystore $JAVA_HOME/lib/security/cacerts -file ${APPLIANCE_FOLDER}/build/cert/archiver-mgmt.crt

# (ii) Copy appliance into tomcat's webapps/
mkdir ${CATALINA_HOME}/webapps/${APPLIANCE_UNIT}

# Change wardest and dist properties in build.xml to ./
xmlstarlet ed -L -u "/project/property[@name='wardest']/@location" -v "./" ${GITHUB_REPOSITORY_FOLDER}/build.xml
xmlstarlet ed -L -u "/project/property[@name='dist']/@location" -v "./" ${GITHUB_REPOSITORY_FOLDER}/build.xml

# Build only specific war file
export TOMCAT_HOME=${CATALINA_HOME}
(cd ${GITHUB_REPOSITORY_FOLDER}; ant ${APPLIANCE_UNIT}_war)

cp ${GITHUB_REPOSITORY_FOLDER}/${APPLIANCE_UNIT}.war ${CATALINA_HOME}/webapps/${APPLIANCE_UNIT}
(cd ${CATALINA_HOME}/webapps/${APPLIANCE_UNIT}; jar xf ${APPLIANCE_UNIT}.war)

rm ${CATALINA_HOME}/webapps/${APPLIANCE_UNIT}/${APPLIANCE_UNIT}.war

ls ${CATALINA_HOME}/webapps/${APPLIANCE_UNIT}

sed -i 's/username=.*$/username=\"'"${MYSQL_USER}"'\"/' ${CATALINA_HOME}/conf/context.xml
sed -i 's/password=.*$/password=\"'"${MYSQL_PASSWORD}"'\"/' ${CATALINA_HOME}/conf/context.xml
sed -i 's/url=.*$/url=\"jdbc:mysql:\/\/'"${MYSQL_SQL_ADDRESS}"':'"${MYSQL_PORT}"'\/'"${MYSQL_DATABASE}"'\"/' ${CATALINA_HOME}/conf/context.xml

# Do not allow external accesses in engine and etl appliances
if [ "${APPLIANCE_UNIT}" = "engine" ] || [ "${APPLIANCE_UNIT}" = "etl" ] ; then

	echo "Applying access restriction from external networks..."
	# Find a way to change allowed addresses with the internal network address
	# xmlstarlet ed -L -s '/Context' -t elem -n 'Valve' \
	#		  -i '/Context/Valve' -t attr -n 'className' -v 'org.apache.catalina.valves.RemoteAddrValve' \
	#                 -i '/Context/Valve' -t attr -n 'allow' -v '172\.17\.\d+\.\d+' \
	#                 ${CATALINA_HOME}/conf/context.xml
fi

if [ "${APPLIANCE_UNIT}" = "retrieval" ]; then
        git clone https://github.com/gciotto/archiver-viewer.git ${CATALINA_HOME}/webapps/${APPLIANCE_UNIT}/ui/archiver-viewer
        git clone https://github.com/slacmshankar/svg_viewer.git ${CATALINA_HOME}/webapps/${APPLIANCE_UNIT}/ui/viewer
fi
