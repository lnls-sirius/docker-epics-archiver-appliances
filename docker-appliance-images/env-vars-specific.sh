#!/bin/bash

DOCKER_MANTAINER_NAME=gciotto

DOCKER_NAME=epics-archiver
DOCKER_RUN_NAME=epics-archiver

NETWORK_ID=epics-archiver-network

APPLIANCE_STORAGE_FOLDER=/opt/epics-archiver-appliances/storage

SHORT_TERM_VOLUME_FOLDER=${APPLIANCE_STORAGE_FOLDER}/sts
SHORT_TERM_VOLUME_NAME=epics-archiver-storage-sts

MEDIUM_TERM_VOLUME_FOLDER=${APPLIANCE_STORAGE_FOLDER}/mts
MEDIUM_TERM_VOLUME_NAME=epics-archiver-storage-mts

LONG_TERM_VOLUME_FOLDER=${APPLIANCE_STORAGE_FOLDER}/lts
LONG_TERM_VOLUME_NAME=epics-archiver-storage-lts

ARCHAPPL_MYIDENTITY=lnls_control_appliance_1
