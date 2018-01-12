#!/bin/bash

#
# A simple bash script to build four different Docker images: one for each EPICS Archiver Appliance
#
# Gustavo Ciotto Pinton
# LNLS - Brazilian Synchrotron Light Source
# Controls Group
#

. ./env-vars-single.sh

set -x
docker build --build-arg ARCHAPPL_MYIDENTITY=${ARCHAPPL_MYIDENTITY} -t ${DOCKER_MANTAINER_NAME}/${DOCKER_NAME}:${DOCKER_TAG} .

