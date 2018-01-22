#!/bin/sh

#
# A simple script to start tomcat service. This script blocks and does not
# allow the container to finish and end.
#

# Waits for MySQL database to start
chmod +x ${APPLIANCE_FOLDER}/build/configuration/wait-for-it/wait-for-it.sh
${APPLIANCE_FOLDER}/build/configuration/wait-for-it/wait-for-it.sh epics-archiver-mysql-db:3306

# Setup all appliances
${APPLIANCE_FOLDER}/build/scripts/setup-appliance.sh

for APPLIANCE_UNIT in "engine" "retrieval" "etl" "mgmt"
do
    export CATALINA_BASE=${CATALINA_HOME}/${APPLIANCE_UNIT}
    ${CATALINA_HOME}/bin/catalina.sh start
done

tail -f /dev/null
