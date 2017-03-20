#!/bin/sh

set -a
set -e
set -u

. ${APPLIANCE_FOLDER}/build/scripts/env-vars.sh

RAND_SRV_PORT=16000

echo xmlstarlet sel -t -v "/appliances/appliance[identity='${ARCHAPPL_MYIDENTITY}']/${APPLIANCE_UNIT}_url" ${ARCHAPPL_APPLIANCES}

APPLIANCE_PORT=$(xmlstarlet sel -t -v "/appliances/appliance[identity='${ARCHAPPL_MYIDENTITY}']/${APPLIANCE_UNIT}_url" ${ARCHAPPL_APPLIANCES} | sed "s/.*://" | sed "s/\/.*//" ) 

echo ${APPLIANCE_PORT}

### Tomcat configuration
# (i) Change tomcat's conf/ files
xmlstarlet ed -L -u '/Server/@port' -v ${RAND_SRV_PORT} ${CATALINA_HOME}/conf/server.xml
xmlstarlet ed -L -u "/Server/Service/Connector[@protocol='HTTP/1.1']/@port" -v ${APPLIANCE_PORT} ${CATALINA_HOME}/conf/server.xml
xmlstarlet ed -L -d "/Server/Service/Connector[@protocol!='HTTP/1.1']" ${CATALINA_HOME}/conf/server.xml

# (ii) Copy appliance into tomcat's webapps/
mkdir ${CATALINA_HOME}/webapps/${APPLIANCE_UNIT}

cp ${GITHUB_REPOSITORY_FOLDER}/${APPLIANCE_UNIT}.war ${CATALINA_HOME}/webapps/${APPLIANCE_UNIT}
(cd ${CATALINA_HOME}/webapps/${APPLIANCE_UNIT}; jar xf ${APPLIANCE_UNIT}.war)

rm ${CATALINA_HOME}/webapps/${APPLIANCE_UNIT}/${APPLIANCE_UNIT}.war

ls ${CATALINA_HOME}/webapps/${APPLIANCE_UNIT}

sed -i 's/username=.*$/username=\"'"${MYSQL_USER}"'\"/' ${CATALINA_HOME}/conf/context.xml
sed -i 's/password=.*$/password=\"'"${MYSQL_PASSWORD}"'\"/' ${CATALINA_HOME}/conf/context.xml
sed -i 's/url=.*$/url=\"jdbc:mysql:\/\/'"${HOST_ADDRESS}"':'"${MYSQL_PORT}"'\/'"${MYSQL_DATABASE}"'\"/' ${CATALINA_HOME}/conf/context.xml

if [ "${APPLIANCE_UNIT}" = "retrieval" ]; then
        git clone https://github.com/gciotto/archiver-viewer.git ${CATALINA_HOME}/webapps/${APPLIANCE_UNIT}/ui/archiver-viewer
fi
