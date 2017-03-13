
FROM tomcat:latest

MAINTAINER Gustavo Ciotto

# user root is required to install all needed packages
USER root

ENV APPLIANCE_NAME epics-archiver-appliances

ENV APPLIANCE_FOLDER /opt/${APPLIANCE_NAME}

RUN mkdir -p ${APPLIANCE_FOLDER}/build/scripts

COPY docker-alpine-update.sh \
     ${APPLIANCE_FOLDER}/build/scripts/

WORKDIR ${APPLIANCE_FOLDER}/build/scripts/

RUN ./docker-alpine-update.sh

COPY env-vars.sh \
	 docker-setup-epics.sh \
	 ${APPLIANCE_FOLDER}/build/scripts/

RUN ./docker-setup-epics.sh

ENV EPICS_HOST_ARCH linux-x86_64
ENV EPICS_CA_ADDR_LIST 10.0.4.69
ENV EPICS_BASE ${EPICS_INSTALL_DIR}/${EPICS_BASE_NAME}


COPY docker-setup-appliances.sh \
	 ${APPLIANCE_FOLDER}/build/scripts/

RUN ./docker-setup-appliances.sh
