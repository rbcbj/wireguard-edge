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

#===============================================================================
# wireguard support functions
#===============================================================================

function wg_config_bootstrap() {
  if [[ ! -d "${CONFIG_DIR}" ]]; then
    mkdir -p "${CONFIG_DIR}"
  fi

  if [[ ! -f "${CONFIG_DIR}/${CONFIG_FILE}" ]]; then
    echo "{}" | tee "${CONFIG_DIR}/${CONFIG_FILE}"
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
  local allowed_ip="${2:-0.0.0.0/0}"

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

function wg_server_consolidate() {
  SERVER_ADDRESS=$(_get ".spec.server.address")
  SERVER_PORT=$(_get ".spec.server.port")
  SERVER_CRED_KEY=$(_get ".spec.server.credential.key")
  SERVER_CRED_PUB=$(_get ".spec.server.credential.port")

  envsubst <<INTERFACE | tee /etc/wireguard/wg0.conf > /dev/null
[Interface]
Address = ${SERVER_ADDRESS}
ListenPort = ${SERVER_PORT}
PrivateKey = ${SERVER_CRED_KEY}
#PostUp = iptables -A FORWARD -i wg0 -j ACCEPT; iptables -A FORWARD -o wg0 -j ACCEPT; iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE  # Optional: Setup forwarding for internet access
#PostDown = iptables -D FORWARD -i wg0 -j ACCEPT; iptables -D FORWARD -o wg0 -j ACCEPT; iptables -t nat -D POSTROUTING -o eth0 -j MASQUERADE  # Cleanup forwarding
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
AllowedIPs = $ALLOWED_IPS
PersistentKeepalive = 25
PEER
  done

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
    -p \"<name>[;allowed_ip]\"
                Configure a peer
                required arg: \"<name>\"
                NOTE: for optional values, just leave blank
                [allowed_ip] default: 0.0.0.0/0; otherwise, allowed ip address

The 'command' (if provided and valid) will be run instead of supervisord
" >&2
    exit $RC
}

wg_config_bootstrap
_del ".peer.list"

while getopts ":ha:b:p:" opt; do
    case "$opt" in
        h) usage ;;
        a) eval wg_server_address $OPTARG ;;
        b) eval wg_server_port $OPTARG ;;
        p) eval wg_peer_add $(sed 's/^/"/; s/$/"/; s/;/" "/g' <<< $OPTARG) ;;
        "?") echo "Unknown option: -$OPTARG"; usage 1 ;;
        ":") echo "No argument value for option: -$OPTARG"; usage 2 ;;
    esac
done
shift $(( OPTIND - 1 ))

wg_server_consolidate
echo "wg0.conf ================================================================"
cat /etc/wireguard/wg0.conf
echo "========================================================================="

nginx-setup

#if [[ $# -ge 1 && -x $(which $1 2>&-) ]]; then
#    exec "$@"
#elif [[ $# -ge 1 ]]; then
#    echo "ERROR: command not found: $1"
#    exit 13
#elif ps -ef | egrep -v grep | grep -q supervisord; then
#    echo "Service already running, please restart container to apply changes"
#else
#    exec ionice -c 3 /usr/bin/supervisord -n -c /etc/supervisor/supervisord.conf </dev/null
#fi