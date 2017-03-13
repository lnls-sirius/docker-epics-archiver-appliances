#!/bin/sh

set -a
set -e
set -u

source ./env-vars.sh

docker build -t ${DOCKER_MANTAINER_NAME}/${DOCKER_NAME} .
