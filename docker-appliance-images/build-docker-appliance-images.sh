#!/bin/bash

#
# A simple bash script to build four different Docker images: one for each EPICS Archiver Appliance
#
# Gustavo Ciotto Pinton
# LNLS - Brazilian Synchrotron Light Source
# Controls Group
#

. ./env-vars-specific.sh

### Build STS, MTS and LTS volumes

DOCKER_STS_CONTAINER=$(docker ps -a | grep ${SHORT_TERM_VOLUME_NAME})

if [ -z ${DOCKER_STS_CONTAINER:+x} ]; then
    echo "${SHORT_TERM_VOLUME_FOLDER} has not been created. Creating... "
    docker create -v ${SHORT_TERM_VOLUME_FOLDER} --name ${SHORT_TERM_VOLUME_NAME} debian &> /dev/null
fi

DOCKER_MTS_CONTAINER=$(docker ps -a | grep ${MEDIUM_TERM_VOLUME_NAME})
if [ -z ${DOCKER_MTS_CONTAINER:+x} ]; then
    echo "${MEDIUM_TERM_VOLUME_FOLDER} has not been created. Creating... "
    docker create -v ${MEDIUM_TERM_VOLUME_FOLDER} --name ${MEDIUM_TERM_VOLUME_NAME} debian &> /dev/null
fi

DOCKER_LTS_CONTAINER=$(docker ps -a | grep ${LONG_TERM_VOLUME_NAME})
if [ -z ${DOCKER_LTS_CONTAINER:+x} ]; then
    echo "${LONG_TERM_VOLUME_FOLDER} has not been created. Creating... "
    docker create -v ${LONG_TERM_VOLUME_FOLDER} --name ${LONG_TERM_VOLUME_NAME} debian &> /dev/null
fi

# The creation process of docker images for the appliances is almost the same. Two parameters are passed into the Dockerfile: the name of the appliance and ist cluster identity.
for APPLIANCE in "mgmt" "retrieval" "etl" "engine"
do
        echo -n "Executing 'docker build --build-arg ARCHAPPL_MYIDENTITY=${ARCHAPPL_MYIDENTITY} --build-arg APPLIANCE_UNIT=${APPLIANCE} -t ${DOCKER_MANTAINER_NAME}/${DOCKER_NAME}-${APPLIANCE} .' ..."
        docker build --build-arg APPLIANCE_UNIT=${APPLIANCE} -t ${DOCKER_MANTAINER_NAME}/${DOCKER_NAME}-${APPLIANCE}:${DOCKER_TAG} .
        echo "Ok!"
done
