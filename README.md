# wireguard-edge

## about the project

As a need of privacy, the `wireguard-edge` project was create to provide a simple solution: provide secure authentication
for private services running in the cloud.

## why to use wireguard-edge

The inspiration for the project was to build a vendor-agnostic authentication approach and enable secure access within
a controlled network without adding complex configurations or solutions.

`wireguard-edge` uses wireguard and nginx to provide a way to control access to aplications while using battle-tested
open-source applications. It provides a way to configure a vpn and a reverse proxy to expose private applications
from within the vpn. 

**This project doesn't route all the traffic to the internet through the wireguard tunnel.** It only focuses on securing
private applications through the tunnel.

## Contribution

This project is free and open source project licensed under the [MIT License](./LICENSE.md). You are free to do whatever you want with it.

Feel free to fork and send PR changes :D