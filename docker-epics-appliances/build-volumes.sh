#!/bin/bash

. ./env-vars-specific.sh

DOCKER_STS_CONTAINER=$(docker ps -a | grep ${SHORT_TERM_VOLUME_NAME})

if [ -z ${DOCKER_STS_CONTAINER:+x} ]; then
    echo ${SHORT_TERM_VOLUME_FOLDER}
    docker create -v ${SHORT_TERM_VOLUME_FOLDER} --name ${SHORT_TERM_VOLUME_NAME} debian
fi

DOCKER_MTS_CONTAINER=$(docker ps -a | grep ${MEDIUM_TERM_VOLUME_NAME})
if [ -z ${DOCKER_MTS_CONTAINER:+x} ]; then   
    echo ${MEDIUM_TERM_VOLUME_FOLDER}
    docker create -v ${MEDIUM_TERM_VOLUME_FOLDER} --name ${MEDIUM_TERM_VOLUME_NAME} debian
fi

DOCKER_LTS_CONTAINER=$(docker ps -a | grep ${LONG_TERM_VOLUME_NAME})

if [ -z ${DOCKER_LTS_CONTAINER:+x} ]; then
    echo ${LONG_TERM_VOLUME_FOLDER}
    docker create -v ${LONG_TERM_VOLUME_FOLDER} --name ${LONG_TERM_VOLUME_NAME} debian
fi
