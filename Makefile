DOCKER_REGISTRY ?= docker.io
DOCKER_USER_GROUP ?= lnlscon
DOCKER_IMAGE_PREFIX = $(DOCKER_REGISTRY)/$(DOCKER_USER_GROUP)

DATE = $(shell date -I)

EPICS_VERSION = R7.0.5

GITHUB_REPOSITORY_URL = https://github.com/lnls-sirius/epicsarchiverap-ldap.git
GITHUB_REPOSITORY_BRANCH = PR-JDK12-master
GITHUB_REPOSITORY_COMMIT =

LABELS += --label "br.com.lnls-sirius.archappl.url=$(GITHUB_REPOSITORY_URL)"
LABELS += --label "br.com.lnls-sirius.archappl.branch=$(GITHUB_REPOSITORY_BRANCH)"
LABELS += --label "br.com.lnls-sirius.epics=$(EPICS_VERSION)"
LABELS += --label "br.com.lnls-sirius.department=GCS"
LABELS += --label "br.com.lnls-sirius.description=Archiver appliances"
LABELS += --label "br.com.lnls-sirius.maintener=Claudio Ferreira Carneiro"
LABELS += --label "br.com.lnls-sirius.repo=https://github.com/lnls-sirius/docker-epics-archiver-appliances"

EPICS_ARCHVIER_BASE_IMG = $(DOCKER_IMAGE_PREFIX)/epics-archiver-base
EPICS_ARCHVIER_BASE_TAG = tomcat9-jdk15-epics$(EPICS_VERSION)-$(GITHUB_REPOSITORY_BRANCH)-$(DATE)

EPICS_ARCHVIER_SINGLE_IMG = $(DOCKER_IMAGE_PREFIX)/epics-archiver-single
EPICS_ARCHVIER_SINGLE_TAG = $(EPICS_ARCHVIER_BASE_TAG)

TOMCAT_BASE_IMAGE = tomcat:9.0.43-jdk15-openjdk-buster
#TOMCAT_BASE_IMAGE = tomcat:9.0.43-jdk8-openjdk-buster
#TOMCAT_BASE_IMAGE = tomcat:8.5.63-jdk8-openjdk-buster

BUILD_ARGS_BASE += --build-arg GITHUB_REPOSITORY_URL=$(GITHUB_REPOSITORY_URL)
BUILD_ARGS_BASE += --build-arg GITHUB_REPOSITORY_BRANCH=$(GITHUB_REPOSITORY_BRANCH)
BUILD_ARGS_BASE += --build-arg GITHUB_REPOSITORY_COMMIT=$(GITHUB_REPOSITORY_COMMIT)
BUILD_ARGS_BASE += --build-arg TOMCAT_BASE_IMAGE=$(TOMCAT_BASE_IMAGE)
BUILD_ARGS_BASE += --build-arg TOMCAT_BASE_IMAGE=$(TOMCAT_BASE_IMAGE)
BUILD_ARGS_BASE += --build-arg EPICS_VERSION=$(EPICS_VERSION)

BUILD_ARGS_SINGLE += --build-arg EPICS_ARCHVIER_BASE_IMG=$(EPICS_ARCHVIER_BASE_IMG)
BUILD_ARGS_SINGLE += --build-arg EPICS_ARCHVIER_BASE_TAG=$(EPICS_ARCHVIER_BASE_TAG)

build: build-base build-single
build-base:
	docker build $(LABELS) $(BUILD_ARGS_BASE)\
		--tag $(EPICS_ARCHVIER_BASE_IMG):$(EPICS_ARCHVIER_BASE_TAG) .


build-single:
	docker build $(LABELS) $(BUILD_ARGS_SINGLE)\
		--tag $(EPICS_ARCHVIER_SINGLE_IMG):$(EPICS_ARCHVIER_SINGLE_TAG) images-single/
push:
	docker push $(EPICS_ARCHVIER_BASE_IMG):$(EPICS_ARCHVIER_BASE_TAG)
	docker push $(EPICS_ARCHVIER_SINGLE_IMG):$(EPICS_ARCHVIER_SINGLE_TAG)
