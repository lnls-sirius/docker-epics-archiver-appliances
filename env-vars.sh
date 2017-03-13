#!/bin/bash

EPICS_BASE_VERSION=3.14.12.6
EPICS_BASE_TAR_NAME=baseR${EPICS_BASE_VERSION}
EPICS_BASE_NAME=base-${EPICS_BASE_VERSION}
EPICS_BASE_URL=https://www.aps.anl.gov/epics/download/base/${EPICS_BASE_TAR_NAME}.tar.gz
EPICS_INSTALL_DIR=/opt

DOCKER_MANTAINER_NAME=gciotto
DOCKER_NAME=epics-archiver-generic
DOCKER_RUN_NAME=epics-archiver-generic

GITHUB_APPLIANCES_BRANCH=develop-php
GITHUB_REPOSITORY_FOLDER=/opt/epicsarchiverap-ldap
GITHUB_REPOSITORY_URL=https://github.com/lnls-sirius/epicsarchiverap-ldap.git
