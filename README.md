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

For the parameters, you can check `docker-entrypoint.sh`:
```
Usage: docker-entrypoint.sh [-opt] [command]
Options (fields in '[]' are optional, '<>' are required):
    -h          This help
    -a "<server ip range>"
    -b "<server port bind>"
    -e "<server public address>"
    -p "<name;address>"
                Configure a peer
                required arg: "<name;address>"
    -s "<service_name;internal_domain;external_domain;service_endpoint">
                Configure a service to be routed
                required arg: "<service_name;internal_domain;external_domain;service_endpoint">
                  service_name: the service name (space not allowed [a-zA-Z0-9.-]
                  internal_domain: the internal domain name
                  external_domain: the external domain name, basically the host for the service_endpoint
                  service_endpoint: the external endpoint to be proxied

The 'command' (if provided and valid) will be run instead of supervisord
```

For a quick TL;DR; you can check this `docker-compose.yml`:
```
services:
  nexus-gate:
    image: rbcbj/nexus-gate:main
    command: |
      -a 10.6.0.1/24
      -b 51820
      -e <the address endpoint of server to be used in clients>
      -p "user;10.6.0.2/32"
      -s 'google;google.internal;www.google.com;https://www.google.com'
    cap_add:
      - NET_ADMIN
    ports:
      - "51820:51820/udp"
    volumes:
      - ./config:/var/lib/wg/
```

> [!NOTE]  
> The use of this solution as a transparent proxy is limited, and it is not fully supported.

The previous example will create a service redirection that will respond to `google.internal` and proxy to external endpoint.

Be mindful that you need to create the correct entry for the DNS. It can be setup in `hosts` or as a proper DNS entry.

`/etc/hosts`:
```
# all entries that are exposed, should point to the tunnel gateway:
10.6.0.1 google.internal
```

## contribution

This project is free and open source project licensed under the [MIT License](./LICENSE.md). You are free to do whatever you want with it.

Feel free to fork and send PR changes :D