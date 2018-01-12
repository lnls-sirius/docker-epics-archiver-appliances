#!/bin/sh

#
# A simple script to start tomcat service. This script blocks and does not
# allow the container to finish and end.
#

# Before starting Tomcat service, change all addresses in lnls_appliances.xml.
# Get local ip address
IP_ADDRESS=$(ip addr show eth0 | grep "inet\b" | awk '{print $2}' | cut -d/ -f1)

sed -i "s:localhost:${IP_ADDRESS}:g" ${ARCHAPPL_APPLIANCES}	

# Setup appliance according to its name, passed by the command docker build
${APPLIANCE_FOLDER}/build/scripts/setup-appliance.sh

# Waits for MySQL database to start
chmod +x ${APPLIANCE_FOLDER}/build/configuration/wait-for-it/wait-for-it.sh
${APPLIANCE_FOLDER}/build/configuration/wait-for-it/wait-for-it.sh epics-archiver-mysql-db:3306


${CATALINA_HOME}/bin/catalina.sh start

tail -f ${CATALINA_HOME}/logs/catalina.out
