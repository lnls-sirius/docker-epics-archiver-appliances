# Docker image for a general EPICS Archiver Appliance.
# It consists of the base image for the mgmt, etl, engine and retrieval Docker containers.

FROM tomcat:9-jdk8-corretto

# User root is required to install all needed packages
USER root

ENV DEBIAN_FRONTEND noninteractive
ENV TZ=America/Sao_Paulo
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

# Updates default image and install required packages
RUN amazon-linux-extras enable epel && yum clean metadata && yum install -y epel-release &&\
    yum install -y \
     ant \
     gcc \
     gcc-c++ \
     git \
     hostname \
     libreadline-dev \
     make \
     make\
     perl \
     tar \
     tzdata \
     tzdata-java \
     wget \
     xmlstarlet \
     &&\
     rm -rf /var/lib/apt/lists/*

ENV APPLIANCE_NAME epics-archiver-appliances
ENV APPLIANCE_FOLDER /opt/${APPLIANCE_NAME}

RUN mkdir -p ${APPLIANCE_FOLDER}/build/scripts

# General EPICS Archiver Appliance Setup
ENV ARCHAPPL_SITEID lnls-control-archiver

# EPICS environment variables
ENV EPICS_VERSION R3.15.8
ENV EPICS_HOST_ARCH linux-x86_64
ENV EPICS_BASE /opt/epics-${EPICS_VERSION}/base
ENV PATH ${EPICS_BASE}/bin/${EPICS_HOST_ARCH}:${PATH}

ENV EPICS_CA_AUTO_ADDR_LIST NO

RUN mkdir -p /opt/epics-${EPICS_VERSION} && cd /opt/epics-${EPICS_VERSION} &&\
    wget https://github.com/epics-base/epics-base/archive/R3.15.8.tar.gz &&\
    cd /opt/epics-${EPICS_VERSION} && tar -zxf R3.15.8.tar.gz && rm R3.15.8.tar.gz &&\
    mv epics-base-R3.15.8 base && cd base && make -j$(nproc)

# Github repository variables
ENV GITHUB_REPOSITORY_FOLDER /opt/epicsarchiverap-ldap
ENV GITHUB_REPOSITORY_URL https://github.com/lnls-sirius/epicsarchiverap-ldap.git

# Clone archiver github's repository
RUN git clone ${GITHUB_REPOSITORY_URL} ${GITHUB_REPOSITORY_FOLDER} && \
     mkdir -p ${APPLIANCE_FOLDER}/build/bin

### Set up mysql connector
ENV MYSQL_CONNECTOR mysql-connector-java-8.0.22

RUN wget -P ${APPLIANCE_FOLDER}/build/bin https://dev.mysql.com/get/Downloads/Connector-J/${MYSQL_CONNECTOR}.tar.gz &&\
     tar -C ${APPLIANCE_FOLDER}/build/bin -xvf ${APPLIANCE_FOLDER}/build/bin/${MYSQL_CONNECTOR}.tar.gz &&\
     cp ${APPLIANCE_FOLDER}/build/bin/${MYSQL_CONNECTOR}/${MYSQL_CONNECTOR}.jar ${CATALINA_HOME}/lib &&\
     rm -R ${APPLIANCE_FOLDER}/build/bin/${MYSQL_CONNECTOR}/


RUN mkdir -p ${APPLIANCE_FOLDER}/configuration
RUN mkdir -p ${APPLIANCE_FOLDER}/storage
# ARCHAPPL_APPLIANCES is always the same for every image, but ARCHAPPL_MYIDENTITY is not. So it needs to be
# defined when the container is started
ENV ARCHAPPL_APPLIANCES ${APPLIANCE_FOLDER}/configuration/lnls_appliances.xml
ENV ARCHAPPL_POLICIES ${APPLIANCE_FOLDER}/configuration/lnls_policies.py
ENV ARCHAPPL_SHORT_TERM_FOLDER ${APPLIANCE_FOLDER}/storage/sts
ENV ARCHAPPL_MEDIUM_TERM_FOLDER ${APPLIANCE_FOLDER}/storage/mts
ENV ARCHAPPL_LONG_TERM_FOLDER ${APPLIANCE_FOLDER}/storage/lts

RUN mkdir -p ${ARCHAPPL_SHORT_TERM_FOLDER}
RUN mkdir -p ${ARCHAPPL_MEDIUM_TERM_FOLDER}
RUN mkdir -p ${ARCHAPPL_LONG_TERM_FOLDER}

RUN mkdir -p ${APPLIANCE_FOLDER}/build/configuration/wait-for-it
RUN git clone https://github.com/vishnubob/wait-for-it.git ${APPLIANCE_FOLDER}/build/configuration/wait-for-it
