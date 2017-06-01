#!/bin/sh

set -a
set -e
set -u

. ${APPLIANCE_FOLDER}/build/scripts/env-vars.sh

RAND_SRV_PORT=16000
MYSQL_SQL_ADDRESS=10.128.1.6

echo xmlstarlet sel -t -v "/appliances/appliance[identity='${ARCHAPPL_MYIDENTITY}']/${APPLIANCE_UNIT}_url" ${ARCHAPPL_APPLIANCES}

APPLIANCE_PORT=$(xmlstarlet sel -t -v "/appliances/appliance[identity='${ARCHAPPL_MYIDENTITY}']/${APPLIANCE_UNIT}_url" ${ARCHAPPL_APPLIANCES} | sed "s/.*://" | sed "s/\/.*//" ) 

echo ${APPLIANCE_PORT}

### Tomcat configuration
# (i) Change tomcat's conf/ files

xmlstarlet ed -L -u '/Server/@port' -v ${RAND_SRV_PORT} ${CATALINA_HOME}/conf/server.xml

if [ "${APPLIANCE_UNIT}" = "engine" ] || [ "${APPLIANCE_UNIT}" = "etl" ] || [ "${APPLIANCE_UNIT}" = "retrieval" ]; then

        xmlstarlet ed -L -u "/Server/Service/Connector[@protocol='HTTP/1.1']/@port" -v ${APPLIANCE_PORT} ${CATALINA_HOME}/conf/server.xml
        # Remove every other connector entry from the conf/server.xml
        xmlstarlet ed -L -d "/Server/Service/Connector[@protocol!='HTTP/1.1']" ${CATALINA_HOME}/conf/server.xml

elif [ "${APPLIANCE_UNIT}" = "mgmt" ]; then

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
                         -i '/Server/Service/Engine/Host/Realm' -t attr -n "connectionURL" -v "ldap://ad1.abtlus.org.br:389" \
                         -i '/Server/Service/Engine/Host/Realm' -t attr -n "alternativeURL" -v "ldap://ad2.abtlus.org.br:389" \
                         -i '/Server/Service/Engine/Host/Realm' -t attr -n "userSearch" -v "(sAMAccountName={0})" \
                         -i '/Server/Service/Engine/Host/Realm' -t attr -n "userSubtree" -v "true" \
                         -i '/Server/Service/Engine/Host/Realm' -t attr -n "userBase" -v "OU=LNLS,DC=abtlus,DC=org,DC=br" \
                         -i '/Server/Service/Engine/Host/Realm' -t attr -n "connectionName" -v "***REMOVED***" \
                         -i '/Server/Service/Engine/Host/Realm' -t attr -n "connectionPassword" -v "***REMOVED***" \
                         -i '/Server/Service/Engine/Host/Realm' -t attr -n "className" -v "org.apache.catalina.realm.JNDIRealm" \
                         ${CATALINA_HOME}/conf/server.xml

fi

# Imports certificate into trusted keystore
keytool -import -alias tomcat -trustcacerts -storepass ***REMOVED*** -noprompt -keystore $JAVA_HOME/lib/security/cacerts -file ${APPLIANCE_FOLDER}/build/cert/archiver-mgmt.crt 

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

        xmlstarlet ed -L -s '/Context' -t elem -n 'Valve' \
                         -i '/Context/Valve' -t attr -n 'className' -v 'org.apache.catalina.valves.RemoteAddrValve' \
                         -i '/Context/Valve' -t attr -n 'allow' -v '172\.17\.\d+\.\d+' \
                       ${CATALINA_HOME}/conf/context.xml
fi

if [ "${APPLIANCE_UNIT}" = "retrieval" ]; then
        git clone https://github.com/gciotto/archiver-viewer.git ${CATALINA_HOME}/webapps/${APPLIANCE_UNIT}/ui/archiver-viewer
        git clone https://github.com/slacmshankar/svg_viewer.git ${CATALINA_HOME}/webapps/${APPLIANCE_UNIT}/ui/viewer
fi
