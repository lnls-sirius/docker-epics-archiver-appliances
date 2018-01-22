#!/bin/sh

#
# A simple script to start tomcat service. This script blocks and does not
# allow the container to finish and end.
#

# Waits for MySQL database to start
chmod +x ${APPLIANCE_FOLDER}/build/configuration/wait-for-it/wait-for-it.sh
${APPLIANCE_FOLDER}/build/configuration/wait-for-it/wait-for-it.sh epics-archiver-mysql-db:3306

# Setup appliance according to its name, passed by the command docker build
${APPLIANCE_FOLDER}/build/scripts/setup-appliance.sh

# Before starting Tomcat service, change cluster inet port of mgmt servlet.

if [ "${APPLIANCE_UNIT}" = "mgmt" ]; then

	# Get local ip address
	IP_ADDRESS=$(ip addr show eth0 | grep "inet\b" | awk '{print $2}' | cut -d/ -f1)

	# Change cluster inet address
	xmlstarlet ed -L -u "/appliances/appliance[identity='${ARCHAPPL_MYIDENTITY}']/cluster_inetport" -v ${IP_ADDRESS}:12000 ${ARCHAPPL_APPLIANCES}

fi

${CATALINA_HOME}/bin/catalina.sh start


ls ${CATALINA_HOME}/webapps/${APPLIANCE_UNIT}
ls ${CATALINA_HOME}/webapps/${APPLIANCE_UNIT}/WEB-INF/classes
ls ${CATALINA_HOME}/logs

tail -f ${CATALINA_HOME}/logs/catalina.out
