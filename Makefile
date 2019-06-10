RELEASE_NAME ?= p4-styleguide

CHART_NAME ?= p4/static

SHELL := /bin/bash

NAMESPACE ?= default

# Static file source repository
GIT_SRC := https://github.com/greenpeace/planet4-styleguide

DEV_CLUSTER ?= p4-development
DEV_PROJECT ?= planet-4-151612
DEV_ZONE ?= us-central1-a

PROD_CLUSTER ?= planet4-production
PROD_PROJECT ?= planet4-production
PROD_ZONE ?= us-central1-a

SED_MATCH ?= [^a-zA-Z0-9._-]
ifeq ($(CIRCLECI),true)
# Configure build variables based on CircleCI environment vars
BUILD_NUM = build-$(CIRCLE_BUILD_NUM)
BRANCH_NAME ?= $(shell sed 's/$(SED_MATCH)/-/g' <<< "$(CIRCLE_BRANCH)")
BUILD_TAG ?= $(shell sed 's/$(SED_MATCH)/-/g' <<< "$(CIRCLE_TAG)")
else
# Not in CircleCI environment, try to set sane defaults
BUILD_NUM = build-local
BRANCH_NAME ?= $(shell git rev-parse --abbrev-ref HEAD | sed 's/$(SED_MATCH)/-/g')
BUILD_TAG ?= $(shell git tag -l --points-at HEAD | tail -n1 | sed 's/$(SED_MATCH)/-/g')
endif



# If BUILD_TAG is blank there's no tag on this commit
ifeq ($(strip $(BUILD_TAG)),)
# Default to branch name
BUILD_TAG := $(BRANCH_NAME)
else
# Consider this the new :latest image
# FIXME: implement build tests before tagging with :latest
PUSH_LATEST := true
endif

REVISION_TAG = $(shell git rev-parse --short HEAD)


test:
	# yamllint .circleci/config.yml
	yamllint values.yaml
	yamllint env/dev/values.yaml
	yamllint env/prod/values.yaml

pull:
	docker pull gcr.io/planet-4-151612/openresty:latest

docker/checkout-master:
	git clone --depth 1 $(GIT_SRC) docker/source
	cd docker/source ; git checkout master
	cd docker/source ; echo `git rev-parse HEAD` > version.txt

docker/checkout-tag:
	git clone --depth 1 $(GIT_SRC) docker/source
	cd docker/source ; git checkout `git tag -l --points-at HEAD | tail -n 1`
	cd docker/source ; echo `git tag -l --points-at HEAD | tail -n 1` > version.txt

docker/public:
	cd docker/source ; npm install
	sudo npm install -g gulp-cli
	cd docker/source ; gulp build
	mv docker/source/dist docker/public

checkout-master: docker/checkout-master

checkout-tag: docker/checkout-tag

build: test pull docker/public
	docker build \
		--tag=gcr.io/planet-4-151612/styleguide:$(BUILD_TAG) \
		--tag=gcr.io/planet-4-151612/styleguide:$(BUILD_NUM) \
		--tag=gcr.io/planet-4-151612/styleguide:$(REVISION_TAG) \
		docker

dev-config:
	gcloud config set project $(DEV_PROJECT)
	gcloud container clusters get-credentials $(DEV_CLUSTER) --zone $(DEV_ZONE) --project $(DEV_PROJECT)

prod-config:
	gcloud config set project $(PROD_PROJECT)
	gcloud container clusters get-credentials $(PROD_CLUSTER) --zone $(PROD_ZONE) --project $(PROD_PROJECT)

dev-push: dev-config
	gcloud auth configure-docker
	docker push gcr.io/planet-4-151612/styleguide:develop
	docker push gcr.io/planet-4-151612/styleguide:$(BUILD_NUM)

prod-push: prod-config
	gcloud auth configure-docker
	docker push gcr.io/planet-4-151612/styleguide:tag
	docker push gcr.io/planet-4-151612/styleguide:$(BUILD_NUM)

dump:
	$(info BUILD_TAG is [${BUILD_TAG}])

dev: test dev-config
	helm init --client-only
	helm repo add p4 https://planet4-helm-charts.storage.googleapis.com && \
	helm repo update
	helm upgrade --install --force --recreate-pods --wait $(RELEASE_NAME) $(CHART_NAME) \
		--namespace=$(NAMESPACE) \
		--values values.yaml \
		--values env/dev/values.yaml

prod: test prod-config
	helm init --client-only
	helm repo add p4 https://planet4-helm-charts.storage.googleapis.com && \
	helm repo update
	helm upgrade --install --force --wait $(RELEASE_NAME) p4/static \
		--namespace=$(NAMESPACE) \
		--values values.yaml \
		--values env/prod/values.yaml
