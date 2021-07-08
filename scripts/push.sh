#!/bin/bash
set -exu
. ./scripts/config.sh
docker push ${EPICS_ARCHVIER_BASE_IMG}:${EPICS_ARCHVIER_BASE_TAG}
docker push ${EPICS_ARCHVIER_SINGLE_IMG}:${EPICS_ARCHVIER_SINGLE_TAG}