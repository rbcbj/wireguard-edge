include ../../utils/Env.mk

PROJECT ?= wireguard-edge
TAG     ?= 0.01

.PHONY: build
build:
	make build-docker