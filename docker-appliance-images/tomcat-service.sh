#!/bin/sh

#
# A simple script to start tomcat service. This script blocks and does not
# allow the container to finish and end.
#

${CATALINA_HOME}/bin/catalina.sh start


ls ${CATALINA_HOME}/webapps/${APPLIANCE_UNIT}
ls ${CATALINA_HOME}/webapps/${APPLIANCE_UNIT}/WEB-INF/classes
ls ${CATALINA_HOME}/logs

tail -f ${CATALINA_HOME}/logs/catalina.out
