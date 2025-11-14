include ../../utils/Env.mk

PROJECT ?= nexus-gate
TAG     ?= 0.0.1

.PHONY: build
build:
	make build-docker