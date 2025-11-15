#!/bin/bash

. /docker-entrypoint.d/docker-env-defaults.sh

CONFIG_DIR=/var/lib/wg/
CONFIG_FILE=wg0.json

#===============================================================================
# jq support function for storage
#===============================================================================

function _add() {
  local path="$1"
  local value="$2"

  if [[ ! -f "${CONFIG_DIR}${CONFIG_FILE}" ]]; then
    echo "{}" > "${CONFIG_DIR}${CONFIG_FILE}"
  fi

  jq --arg value "$value" \
     "$path |= (if . == null then [\$value] else . + [\$value] end)" "${CONFIG_DIR}${CONFIG_FILE}" > "${CONFIG_DIR}_${CONFIG_FILE}"
   mv "${CONFIG_DIR}_${CONFIG_FILE}" "${CONFIG_DIR}${CONFIG_FILE}"
}

function _del() {
  local path="$1"

  if [[ ! -f "${CONFIG_DIR}${CONFIG_FILE}" ]]; then
    echo "{}" > "${CONFIG_DIR}${CONFIG_FILE}"
  fi

  jq "del($path)" "${CONFIG_DIR}${CONFIG_FILE}" > "${CONFIG_DIR}_${CONFIG_FILE}"
  mv "${CONFIG_DIR}_${CONFIG_FILE}" "${CONFIG_DIR}${CONFIG_FILE}"
}

function _flatten_keys() {
  local path="$1"

  jq -r "$path | keys | join(\" \")" "${CONFIG_DIR}${CONFIG_FILE}"
}

function _get() {
  local path="${1}"

  if [[ ! -f "${CONFIG_DIR}${CONFIG_FILE}" ]]; then
    echo ":: not found"
    exit 1
  fi

  jq -r "$path" "${CONFIG_DIR}${CONFIG_FILE}"
}

function _set() {
  local path="${1}"
  local value="$2"

  if [[ ! -f "${CONFIG_DIR}${CONFIG_FILE}" ]]; then
    echo "{}" > "${CONFIG_DIR}${CONFIG_FILE}"
  fi

  jq --arg value "$value" \
     "$path |= (if . == null then \$value else \$value end)" "${CONFIG_DIR}${CONFIG_FILE}" > "${CONFIG_DIR}_${CONFIG_FILE}"
  mv "${CONFIG_DIR}_${CONFIG_FILE}" "${CONFIG_DIR}${CONFIG_FILE}"
}

#===============================================================================
# nginx reverse router
#===============================================================================

nginx-set-site() {
    local site="${1}"

    echo ":: setting-up ${site}"

    # remove all enabled configurations
    rm /etc/nginx/sites-enabled/*

    # setup site configuration
    if [ -f "/etc/nginx/sites-available/${site}" ]; then
        ln -s "/etc/nginx/sites-available/${site}" /etc/nginx/sites-enabled/default
    fi
}

nginx-setup() {
    sed 's/client_max_body_size.*$/client_max_body_size '${CLIENT_MAX_BODY_SIZE}';/' -i /etc/nginx/snippet/file-upload-size.conf
}

function nginx_service_add() {
  local service_name="${1}"
  local service_internal="${2}"
  local service_external="${3}"
  local service_endpoint="${4}"

  (
    export SERVICE_NAME="${service_name}"
    export SERVICE_INTERNAL="${service_internal}"
    export SERVICE_EXTERNAL="${service_external}"
    export SERVICE_ENDPOINT="${service_endpoint}"

    envsubst '$SERVICE_NAME $SERVICE_ENDPOINT $SERVICE_INTERNAL $SERVICE_EXTERNAL' < /etc/nginx/sites-template/service.conf > /etc/nginx/sites-enabled/${service_name}.conf
  )
}

#===============================================================================
# wireguard support functions
#===============================================================================

function wg_config_bootstrap() {
  if [[ ! -d "${CONFIG_DIR}" ]]; then
    mkdir -p "${CONFIG_DIR}"
  fi

  if [[ ! -f "${CONFIG_DIR}/${CONFIG_FILE}" ]]; then
    echo "{}" | tee "${CONFIG_DIR}/${CONFIG_FILE}" > /dev/null
  fi

  if [[ "$(_get ".spec.server.credential.key")" == "null" ]]; then
    _set ".spec.server.credential.key" "$(wg genkey)"
  fi

  if [[ "$(_get ".spec.server.credential.pub")" == "null" ]]; then
    _set ".spec.server.credential.pub" $(echo "$(_get ".spec.server.credential.key")" | wg pubkey)
  fi
}

function wg_peer_add() {
  local name="$1"
  local address="$2"
  local allowed_ip="${3:-0.0.0.0/0}"

  _set ".spec.peers.${name}.address" "$address"

  if [[ "$(_get ".spec.peers.${name}.credential.key")" == "null" ]]; then
    _set ".spec.peers.${name}.credential.key" "$(wg genkey)"
  fi

  if [[ "$(_get ".spec.peers.${name}.credential.pub")" == "null" ]]; then
    _set ".spec.peers.${name}.credential.pub" $(echo "$(_get ".spec.peers.${name}.credential.key")" | wg pubkey)
  fi

  _set ".spec.peers.${name}.allowed_ips" "$allowed_ip"
}

function wg_server_address() {
  local address="$1"

  _set ".spec.server.address" "$address"
}

function wg_consolidate_wg0() {
  SERVER_ADDRESS=$(_get ".spec.server.address")
  SERVER_PORT=$(_get ".spec.server.port")
  SERVER_CRED_KEY=$(_get ".spec.server.credential.key")
  SERVER_CRED_PUB=$(_get ".spec.server.credential.port")

  envsubst <<INTERFACE | tee /etc/wireguard/wg0.conf > /dev/null
[Interface]
Address = ${SERVER_ADDRESS}
ListenPort = ${SERVER_PORT}
PrivateKey = ${SERVER_CRED_KEY}
INTERFACE

  # transform flattened peers list into array
  IFS=' ' read -r -a PEERS <<< $(_flatten_keys ".spec.peers")

  for PEER in "${PEERS[@]}"; do
    PEER=$(echo $PEER | sed 's/"//g')
    CRED_KEY=$(_get ".spec.peers.${PEER}.credential.key")
    CRED_PUB=$(_get ".spec.peers.${PEER}.credential.pub")
    ALLOWED_IPS=$(_get ".spec.peers.${PEER}.allowed_ips")

    envsubst <<PEER | tee -a /etc/wireguard/wg0.conf > /dev/null

[Peer]
PublicKey = $CRED_PUB
AllowedIPs = $SERVER_ADDRESS
PersistentKeepalive = 25
PEER
  done

  echo "wg0.conf ================================================================"
  cat /etc/wireguard/wg0.conf
  echo "========================================================================="
}

function wg_consolidate_clients() {
  SERVER_ADDRESS=$(_get ".spec.server.address")
  SERVER_ENDPOINT=$(_get ".spec.server.endpoint")
  SERVER_PORT=$(_get ".spec.server.port")
  SERVER_CRED_PUB=$(_get ".spec.server.credential.pub")

  IFS=' ' read -r -a PEERS <<< $(_flatten_keys ".spec.peers")

  for PEER in "${PEERS[@]}"; do
    PEER=$(echo $PEER | sed 's/"//g')
    ADDRESS=$(_get ".spec.peers.${PEER}.address")
    CRED_KEY=$(_get ".spec.peers.${PEER}.credential.key")
    CRED_PUB=$(_get ".spec.peers.${PEER}.credential.pub")
    ALLOWED_IPS=$(_get ".spec.peers.${PEER}.allowed_ips")

    echo ":: peer => $PEER"
    echo "========================================================================="
    envsubst <<PEER
[Interface]
Address = ${ADDRESS}
PrivateKey = ${CRED_KEY}

[Peer]
PublicKey = ${SERVER_CRED_PUB}
Endpoint = ${SERVER_ENDPOINT}:${SERVER_PORT}
AllowedIPs = ${SERVER_ADDRESS}
PersistentKeepalive = 25
PEER
    echo "========================================================================="
  done
}

function wg_server_endpoint() {
  local endpoint="$1"

  _set ".spec.server.endpoint" "$endpoint"
}

function wg_server_port() {
  local port="$1"

  _set ".spec.server.port" "$port"
}

#!/usr/bin/env bash
#===============================================================================
#          FILE: docker-entrypoint.sh
#
#         USAGE: ./docker-entrypoint.sh
#
#   DESCRIPTION: Entrypoint for docker container
#
#       OPTIONS: ---
#  REQUIREMENTS: ---
#          BUGS: ---
#         NOTES: ---
#        AUTHOR: Robson Braga (contato@robsonjr.com.nbr),
#  ORGANIZATION:
#       CREATED: 11/09/2025 19:15
#      REVISION: 1.0
#===============================================================================

set -o nounset                              # Treat unset variables as an error

### usage: Help
# Arguments:
#   none)
# Return: Help text
usage() { local RC="${1:-0}"
    echo "Usage: ${0##*/} [-opt] [command]
Options (fields in '[]' are optional, '<>' are required):
    -h          This help
    -a \"<server ip range>\"
    -b \"<server port bind>\"
    -e \"<server public address>\"
    -p \"<name;address>\"
                Configure a peer
                required arg: \"<name;address>\"
    -s \"<service_name;internal_domain;external_domain;service_endpoint\">
                Configure a service to be routed
                required arg: \"<service_name;internal_domain;external_domain;service_endpoint\">
                  service_name: the service name (space not allowed [a-zA-Z0-9.-]
                  internal_domain: the internal domain name
                  external_domain: the external domain name, basically the host for the service_endpoint
                  service_endpoint: the external endpoint to be proxied

The 'command' (if provided and valid) will be run instead of supervisord
" >&2
    exit $RC
}

wg_config_bootstrap
_del ".peer.list"

while getopts ":ha:b:e:p:s:" opt; do
    case "$opt" in
        h) usage ;;
        a) eval wg_server_address $OPTARG ;;
        b) eval wg_server_port $OPTARG ;;
        e) eval wg_server_endpoint $OPTARG ;;
        p) eval wg_peer_add $(sed 's/^/"/; s/$/"/; s/;/" "/g' <<< $OPTARG) ;;
        s) eval nginx_service_add $(sed 's/^/"/; s/$/"/; s/;/" "/g' <<< $OPTARG) ;;
        "?") echo "Unknown option: -$OPTARG"; usage 1 ;;
        ":") echo "No argument value for option: -$OPTARG"; usage 2 ;;
    esac
done
shift $(( OPTIND - 1 ))

wg_consolidate_wg0
wg_consolidate_clients

nginx-setup

if [[ $# -ge 1 && -x $(which $1 2>&-) ]]; then
    exec "$@"
elif [[ $# -ge 1 ]]; then
    echo "ERROR: command not found: $1"
    exit 13
elif ps -ef | egrep -v grep | grep -q supervisord; then
    echo "Service already running, please restart container to apply changes"
else
    exec ionice -c 3 /usr/bin/supervisord -n -c /etc/supervisor/supervisord.conf </dev/null
fi