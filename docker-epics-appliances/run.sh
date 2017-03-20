#!/bin/bash

. ./env-vars-specific.sh

for APPLIANCE in "engine" "retrieval" "etl" "mgmt" 
#for APPLIANCE in "mgmt" 
do

        CONTAINERS=$(docker ps -a | grep ${DOCKER_RUN_NAME}-${APPLIANCE})

        if [ ! -z "$CONTAINERS" ]; then
            docker stop ${DOCKER_RUN_NAME}-${APPLIANCE}
            docker rm ${DOCKER_RUN_NAME}-${APPLIANCE}
        fi

        APPLIANCE_PORT=$(xmlstarlet sel -t -v "/appliances/appliance[identity='${ARCHAPPL_MYIDENTITY}']/${APPLIANCE}_url" ../lnls_appliances.xml | sed "s/.*://" | sed "s/\/.*//" )

        echo ${APPLIANCE_PORT} - ${APPLIANCE}

        docker run -d --name=${DOCKER_RUN_NAME}-${APPLIANCE} --dns=10.0.0.71 --dns=10.0.0.72 \
            -p ${APPLIANCE_PORT}:${APPLIANCE_PORT} --network=${NETWORK_ID} \
            --volumes-from=${SHORT_TERM_VOLUME_NAME} --volumes-from=${MEDIUM_TERM_VOLUME_NAME} --volumes-from=${LONG_TERM_VOLUME_NAME} \
            ${DOCKER_MANTAINER_NAME}/${DOCKER_NAME}-${APPLIANCE}
done
