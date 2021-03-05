# Docker image for mgmt, retrieval, etl and engine servlets. It receives two
# arguments: the first is the name of the appliance this image will belong to and
# the second is the name of the appliance (mgmt, retrieval, etl or engine).
ARG EPICS_ARCHVIER_BASE_IMG
ARG EPICS_ARCHVIER_BASE_TAG

FROM ${EPICS_ARCHVIER_BASE_IMG}:${EPICS_ARCHVIER_BASE_TAG}
#RUN update-ca-trust extract \
#  && ln -fs /etc/pki/ca-trust/extracted/java/cacerts ${JAVA_HOME}/jre/lib/security/cacerts

# user root is required to install all needed packages
USER root

ENV APPLIANCE_BASE_JMX_PORT 9050
ENV APPLIANCE_NAME epics-archiver-appliances

ENV BASE_TOMCAT_SERVER_PORT 16000
ENV APPLIANCE_FOLDER /opt/${APPLIANCE_NAME}

RUN mkdir -p ${APPLIANCE_FOLDER}/all
COPY build-appliance.bash \
     setup-appliance.bash \
     tomcat-service.bash \
     ${APPLIANCE_FOLDER}/build/scripts/

COPY configuration/context.xml ${CATALINA_HOME}/conf/context.xml

RUN mkdir ${APPLIANCE_FOLDER}/build/cert/

RUN ${APPLIANCE_FOLDER}/build/scripts/build-appliance.bash

ENV APPLIANCE_CERTS_FOLDER ${APPLIANCE_FOLDER}/certs

CMD ["bash", "-c", "${APPLIANCE_FOLDER}/build/scripts/tomcat-service.bash"]
