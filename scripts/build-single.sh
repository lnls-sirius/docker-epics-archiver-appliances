#!/bin/bash
set -exu
. ./scripts/config.sh

docker build \
	--label "br.com.lnls-sirius.archappl.branch=${GITHUB_REPOSITORY_BRANCH}" \
	--label "br.com.lnls-sirius.archappl.url=${GITHUB_REPOSITORY_URL}" \
	--label "br.com.lnls-sirius.description=Archiver appliances" \
	--label "br.com.lnls-sirius.epics=${EPICS_VERSION}" \
	--label "org.opencontainers.image.authors=${AUTHOR}" \
	--label "org.opencontainers.image.created=${BUILD_DATE_RFC339}" \
	--label "org.opencontainers.image.licenses=${LICENSE}" \
	--label "org.opencontainers.image.revision=${COMMIT}" \
	--label "org.opencontainers.image.source=${REPOSITORY}" \
	--label "org.opencontainers.image.url=${REPOSITORY}" \
	--label "org.opencontainers.image.vendor=${VENDOR}" \
	--build-arg "GITHUB_REPOSITORY_URL=${GITHUB_REPOSITORY_URL}" \
	--build-arg "GITHUB_REPOSITORY_BRANCH=${GITHUB_REPOSITORY_BRANCH}" \
	--build-arg "GITHUB_REPOSITORY_COMMIT=${GITHUB_REPOSITORY_COMMIT}" \
	--build-arg "TOMCAT_BASE_IMAGE=${TOMCAT_BASE_IMAGE}" \
	--build-arg "EPICS_VERSION=${EPICS_VERSION}" \
	--build-arg "EPICS_ARCHVIER_BASE_IMG=${EPICS_ARCHVIER_BASE_IMG}" \
	--build-arg "EPICS_ARCHVIER_BASE_TAG=${EPICS_ARCHVIER_BASE_TAG}" \
	--tag ${EPICS_ARCHVIER_SINGLE_IMG}:${EPICS_ARCHVIER_SINGLE_TAG} \
	images-single/
