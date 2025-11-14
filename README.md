# NexusGate

## about the project

As a need of privacy, the project was created to provide a simple solution: provide secure authentication
for services running in private servers which should not be exposed to public network.

## why to use NexusGate

This project is inspired by the idea to build a vendor-agnostic authentication solution that enables secure and authenticated, 
access to internal systems through a protected tunnel, while preventing it to be exposed to public network. 

This approach is valuable for projects that still requires security hardening and/or private services that need to be 
accessed without complex configurations or solutions.

NexusGate uses wireguard and nginx to provide a way to control access to applications while using battle-tested
open-source applications. It provides a way to configure a vpn and a reverse proxy to expose private applications
from within the vpn. 

**This project doesn't route all the traffic to the internet through the wireguard tunnel.** It only focuses on securing
private applications through the secure tunnel.

## how to use the project

## contribution

This project is free and open source project licensed under the [MIT License](./LICENSE.md). You are free to do whatever you want with it.

Feel free to fork and send PR changes :D