#!/bin/bash

. ./env-vars-specific.sh

./build-volumes.sh

for APPLIANCE in "mgmt" "retrieval" "etl" "engine"
do
        echo "docker build --build-arg ARCHAPPL_MYIDENTITY=lnls_control_appliance_1 --build-arg APPLIANCE_UNIT=${APPLIANCE} -t ${DOCKER_MANTAINER_NAME}/${DOCKER_NAME}-${APPLIANCE} ."
        docker build --build-arg ARCHAPPL_MYIDENTITY=${ARCHAPPL_MYIDENTITY} --build-arg APPLIANCE_UNIT=${APPLIANCE} -t ${DOCKER_MANTAINER_NAME}/${DOCKER_NAME}-${APPLIANCE} .
done
