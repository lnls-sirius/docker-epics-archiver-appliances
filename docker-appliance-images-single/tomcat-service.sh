#!/bin/sh

#
# A simple script to start tomcat service. This script blocks and does not
# allow the container to finish and end.
#

# Setup all appliances
${APPLIANCE_FOLDER}/build/scripts/setup-appliance.sh

# Waits for MySQL database to start
chmod +x ${APPLIANCE_FOLDER}/build/configuration/wait-for-it/wait-for-it.sh
${APPLIANCE_FOLDER}/build/configuration/wait-for-it/wait-for-it.sh epics-archiver-mysql-db:3306

for APPLIANCE_UNIT in "mgmt" "engine" "retrieval" "etl"
do
    export CATALINA_BASE=${CATALINA_HOME}/${APPLIANCE_UNIT}
    ${CATALINA_HOME}/bin/catalina.sh start
done

tail -f /dev/null
