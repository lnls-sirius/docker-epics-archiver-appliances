
FROM tomcat:9-alpine

MAINTAINER Gustavo Ciotto

# user root is required to install all needed packages
USER root

ENV APPLIANCE_NAME epics-archiver-appliances

ENV APPLIANCE_FOLDER /opt/${APPLIANCE_NAME}

RUN mkdir -p ${APPLIANCE_FOLDER}/build/scripts

COPY docker-alpine-update.sh \
     env-vars.sh \
     ${APPLIANCE_FOLDER}/build/scripts/

RUN ${APPLIANCE_FOLDER}/build/scripts/docker-alpine-update.sh


