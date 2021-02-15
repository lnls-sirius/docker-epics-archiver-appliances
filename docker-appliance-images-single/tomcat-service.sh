#!/bin/sh
# A simple script to start tomcat service. This script blocks and does not
# allow the container to finish and end.
set -a
set -e
set -u

# Waits for MySQL database to start
chmod +x ${APPLIANCE_FOLDER}/build/configuration/wait-for-it/wait-for-it.sh
${APPLIANCE_FOLDER}/build/configuration/wait-for-it/wait-for-it.sh epics-archiver-mysql-db:3306

# Setup all appliances
${APPLIANCE_FOLDER}/build/scripts/setup-appliance.sh

export JMX_PORT=${APPLIANCE_BASE_JMX_PORT}
for APPLIANCE_UNIT in "engine" "retrieval" "etl" "mgmt"; do
    echo "Appliance ${APPLIANCE_UNIT}, JMX_PORT=${JMX_PORT}"
    export CATALINA_BASE=${CATALINA_HOME}/${APPLIANCE_UNIT}
    export CATALINA_OPTS="${JAVA_OPTS} -Dlog4j.debug -Dcom.sun.management.jmxremote -Dcom.sun.management.jmxremote.port=${JMX_PORT} -Dcom.sun.management.jmxremote.ssl=false -Dcom.sun.management.jmxremote.authenticate=false"
    JMX_PORT=$((JMX_PORT + 1))
    ${CATALINA_HOME}/bin/catalina.sh start
done

tail -f /dev/null
