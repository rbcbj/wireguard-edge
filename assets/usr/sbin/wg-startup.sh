#!/bin/sh

# Set up WireGuard interface
ip link add wg0 type wireguard
ip link set wg0 up

# Configure WireGuard based on the config file
wg-quick up wg0

# Enable IP forwarding (if needed)
# echo 1 > /proc/sys/net/ipv4/ip_forward

# Keep the container running
tail -f /dev/null