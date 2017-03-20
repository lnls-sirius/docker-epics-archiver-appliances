#!/bin/bash

set -a
set -e
set -u

source env-vars-specific.sh

APPLIANCE=mgmt

docker build --build-arg ARCHAPPL_MYIDENTITY=lnls_control_appliance_1 --build-arg APPLIANCE_UNIT=${APPLIANCE} -t ${DOCKER_MANTAINER_NAME}/${DOCKER_NAME}-${APPLIANCE} .
