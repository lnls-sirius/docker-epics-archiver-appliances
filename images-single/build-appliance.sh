#!/bin/bash
set -e
set -x
set -u

for APPLIANCE_UNIT in "mgmt" "engine" "retrieval" "etl"; do

     # Change wardest and dist properties in build.xml to ./
     xmlstarlet ed -L -u "/project/property[@name='wardest']/@location" -v "./" ${GITHUB_REPOSITORY_FOLDER}/build.xml
     xmlstarlet ed -L -u "/project/property[@name='dist']/@location" -v "./" ${GITHUB_REPOSITORY_FOLDER}/build.xml

     # Build only specific war file
     export TOMCAT_HOME=${CATALINA_HOME}
     (
         cd ${GITHUB_REPOSITORY_FOLDER}
         ant -quiet ${APPLIANCE_UNIT}_war
     )

     mkdir --verbose --parents ${CATALINA_HOME}/${APPLIANCE_UNIT}/webapps/${APPLIANCE_UNIT}

     mv --verbose ${GITHUB_REPOSITORY_FOLDER}/${APPLIANCE_UNIT}.war ${CATALINA_HOME}/${APPLIANCE_UNIT}/webapps/${APPLIANCE_UNIT}
     (
         cd ${CATALINA_HOME}/${APPLIANCE_UNIT}/webapps/${APPLIANCE_UNIT}
         jar xf ${APPLIANCE_UNIT}.war
     )

     rm --verbose ${CATALINA_HOME}/${APPLIANCE_UNIT}/webapps/${APPLIANCE_UNIT}/${APPLIANCE_UNIT}.war
 done
