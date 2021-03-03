ARG TOMCAT_BASE_IMAGE
FROM ${TOMCAT_BASE_IMAGE}
ARG EPICS_VERSION

# User root is required to install all needed packages
USER root

ENV DEBIAN_FRONTEND noninteractive
ENV TZ=America/Sao_Paulo
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

# Updates default image and install required packages
RUN set -x;\
    apt update -y; \
    apt install -y \
       ant \
       g++ \
       gcc \
       git \
       hostname \
       libreadline-dev \
       make \
       perl \
       tar \
       tzdata \
       wget \
       xmlstarlet \
       ;\
    rm -rf /var/lib/apt/lists/*

ENV APPLIANCE_NAME epics-archiver-appliances
ENV APPLIANCE_FOLDER /opt/${APPLIANCE_NAME}

RUN mkdir -p ${APPLIANCE_FOLDER}/build/scripts

# General EPICS Archiver Appliance Setup
ENV ARCHAPPL_SITEID lnls-control-archiver

# EPICS environment variables
ENV EPICS_VERSION ${EPICS_VERSION}
ENV EPICS_HOST_ARCH linux-x86_64
ENV EPICS_BASE /opt/epics-${EPICS_VERSION}/base
ENV PATH ${EPICS_BASE}/bin/${EPICS_HOST_ARCH}:${PATH}

ENV EPICS_CA_AUTO_ADDR_LIST NO

RUN set -e; set -x;\
    mkdir -p /opt/epics-${EPICS_VERSION};\
    cd /opt/epics-${EPICS_VERSION};\
    wget https://github.com/epics-base/epics-base/archive/${EPICS_VERSION}.tar.gz;\
    tar -zxf ${EPICS_VERSION}.tar.gz;\
    rm -v ${EPICS_VERSION}.tar.gz;\
    mv epics-base-${EPICS_VERSION} base;\
    cd base;\
    make -j$(nproc)

# Github repository variables
ENV GITHUB_REPOSITORY_FOLDER /opt/epicsarchiverap-ldap
ARG GITHUB_REPOSITORY_URL
ARG GITHUB_REPOSITORY_BRANCH
ARG GITHUB_REPOSITORY_COMMIT

# Clone archiver github's repository
RUN set -x;\
    set -e;\
    git clone ${GITHUB_REPOSITORY_URL} ${GITHUB_REPOSITORY_FOLDER};\
    mkdir -p ${APPLIANCE_FOLDER}/build/bin;\
    cd ${GITHUB_REPOSITORY_FOLDER};\
    git checkout ${GITHUB_REPOSITORY_BRANCH};\
    if [ ! -z "${GITHUB_REPOSITORY_COMMIT}" ]; then git checkout ${GITHUB_REPOSITORY_COMMIT}; fi

### Set up mysql connector
ENV MYSQL_CONNECTOR mysql-connector-java-8.0.22

RUN wget -P ${APPLIANCE_FOLDER}/build/bin https://dev.mysql.com/get/Downloads/Connector-J/${MYSQL_CONNECTOR}.tar.gz &&\
     tar -C ${APPLIANCE_FOLDER}/build/bin -xvf ${APPLIANCE_FOLDER}/build/bin/${MYSQL_CONNECTOR}.tar.gz &&\
     cp ${APPLIANCE_FOLDER}/build/bin/${MYSQL_CONNECTOR}/${MYSQL_CONNECTOR}.jar ${CATALINA_HOME}/lib &&\
     rm -R ${APPLIANCE_FOLDER}/build/bin/${MYSQL_CONNECTOR}/


RUN mkdir -p ${APPLIANCE_FOLDER}/configuration
RUN mkdir -p ${APPLIANCE_FOLDER}/storage

# ARCHAPPL_APPLIANCES is always the same for every image, but ARCHAPPL_MYIDENTITY is not.
# So it needs to be defined when the container is started
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
