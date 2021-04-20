#!/bin/bash
# A simple script to start tomcat service. This script blocks and does not
# allow the container to finish and end.
set -a
set -e
set -u

# Waits for MySQL database to start
chmod +x ${APPLIANCE_FOLDER}/build/configuration/wait-for-it/wait-for-it.sh
${APPLIANCE_FOLDER}/build/configuration/wait-for-it/wait-for-it.sh epics-archiver-mysql-db:3306

# Setup all appliances
${APPLIANCE_FOLDER}/build/scripts/setup-appliance.bash

export JMX_PORT=${APPLIANCE_BASE_JMX_PORT}
for APPLIANCE_UNIT in "engine" "retrieval" "etl" "mgmt"; do
    OPTS=""
    OPTS="${OPTS} -Dlog4j.debug"
    OPTS="${OPTS} -Dcom.sun.management.jmxremote"
    OPTS="${OPTS} -Dcom.sun.management.jmxremote.port=${JMX_PORT}"
    OPTS="${OPTS} -Dcom.sun.management.jmxremote.rmi.port=${JMX_PORT}"
    OPTS="${OPTS} -Dcom.sun.management.jmxremote.ssl=false"
    OPTS="${OPTS} -Dcom.sun.management.jmxremote.authenticate=false"

    set +u
    # Appliance specific OPTS
    [[ "${APPLIANCE_UNIT}" = "engine" ]]    && OPTS="${OPTS} ${JAVA_OPTS_ENGINE}"
    [[ "${APPLIANCE_UNIT}" = "retrieval" ]] && OPTS="${OPTS} ${JAVA_OPTS_RETRIEVAL}"
    [[ "${APPLIANCE_UNIT}" = "etl" ]]       && OPTS="${OPTS} ${JAVA_OPTS_ETL}"
    [[ "${APPLIANCE_UNIT}" = "mgmt" ]]      && OPTS="${OPTS} ${JAVA_OPTS_MGMT}"
    set -u

    echo "Appliance ${APPLIANCE_UNIT}, JMX_PORT=${JMX_PORT}"
    export CATALINA_BASE=${CATALINA_HOME}/${APPLIANCE_UNIT}
    export CATALINA_OPTS="${JAVA_OPTS} ${OPTS}"
    ${CATALINA_HOME}/bin/catalina.sh start

    JMX_PORT=$((JMX_PORT + 1))
done

tail -f /dev/null
