#!/bin/bash

CLIENT_MAX_BODY_SIZE=${CLIENT_MAX_BODY_SIZE:-"64m"}
ENV=${ENV:-"prod"}

WG_CONFIG=/etc/wireguard/wg0.conf