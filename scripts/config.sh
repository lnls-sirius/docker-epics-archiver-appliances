#!/bin/bash
set -exu

DOCKER_REGISTRY=dockerregistry.lnls-sirius.com.br
DOCKER_USER_GROUP=gas
DOCKER_IMAGE_PREFIX=${DOCKER_REGISTRY}/${DOCKER_USER_GROUP}

AUTHOR="Claudio F. Carneiro <claudiofcarneiro@hotmail.com>"
BRANCH=$(git branch --no-color --show-current)
BUILD_DATE=$(date -I)
BUILD_DATE_RFC339=$(date --rfc-3339=seconds)
COMMIT=$(git rev-parse --short HEAD)
DEPARTMENT=GAS
REPOSITORY=$(git remote show origin | grep Fetch | awk '{ print $3 }')
VENDOR=CNPEM

EPICS_VERSION=R7.0.5

GITHUB_REPOSITORY_URL=https://github.com/lnls-sirius/epicsarchiverap-ldap.git
GITHUB_REPOSITORY_BRANCH=PR-JDK12-master
GITHUB_REPOSITORY_COMMIT=master

LICENSE=""

EPICS_ARCHVIER_BASE_IMG=${DOCKER_IMAGE_PREFIX}/epics-archiver-base
EPICS_ARCHVIER_BASE_TAG=tomcat9-jdk15-epics${EPICS_VERSION}-${GITHUB_REPOSITORY_BRANCH}-${BUILD_DATE}

EPICS_ARCHVIER_SINGLE_IMG=${DOCKER_IMAGE_PREFIX}/epics-archiver-single
EPICS_ARCHVIER_SINGLE_TAG=${EPICS_ARCHVIER_BASE_TAG}

TOMCAT_BASE_IMAGE=tomcat:9.0.43-jdk15-openjdk-buster
