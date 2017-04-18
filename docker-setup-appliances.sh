#!/bin/sh

set -a
set -e
set -u

. ./env-vars.sh

git clone --branch=${GITHUB_APPLIANCES_BRANCH} ${GITHUB_REPOSITORY_URL} ${GITHUB_REPOSITORY_FOLDER}

