
FROM gciotto/epics-archiver-generic

MAINTAINER Gustavo Ciotto

USER root

ARG ARCHAPPL_MYIDENTITY=lnls_control_appliance_1
ARG APPLIANCE_UNIT=mgmt

ENV ARCHAPPL_MYIDENTITY ${ARCHAPPL_MYIDENTITY}
ENV APPLIANCE_UNIT=${APPLIANCE_UNIT}

# user root is required to install all needed packages
USER root

ENV APPLIANCE_NAME epics-archiver-appliances

ENV APPLIANCE_FOLDER /opt/${APPLIANCE_NAME}

# APPLIANCE_UNIT should be defined on building throught --build-arg
# ENV APPLIANCE_UNIT mgmt

RUN mkdir -p ${APPLIANCE_FOLDER}/${APPLIANCE_UNIT}

COPY setup-appliance-specific.sh \
     docker-tomcat-init.sh \
     ${APPLIANCE_FOLDER}/build/scripts/

COPY context.xml \
     ${CATALINA_HOME}/conf/context.xml

RUN ${APPLIANCE_FOLDER}/build/scripts/setup-appliance-specific.sh

CMD ["/opt/epics-archiver-appliances/build/scripts/docker-tomcat-init.sh"]


