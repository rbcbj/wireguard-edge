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
    -p "<name;address>[;allowed_ip]"
                Configure a peer
                required arg: "<name>"
                NOTE: for optional values, just leave blank
                [allowed_ip] default: 0.0.0.0/0; otherwise, allowed ip address
    -s "<service_name;service_fqdn;service_endpoint">
                Configure a service to be routed
                required arg: "<service_name;service_fqdn;service_endpoint">
                  service_name: the service name (space not allowed [a-zA-Z0-9.-]
                  service_fqdn: the service address to be used for serving
                  service_endpoint: the internal service address to expose through tunnel

The 'command' (if provided and valid) will be run instead of supervisord
```

For a quick TL;DR; you can check this `docker-compose.yml`:
```
services:
  wireguard-edge:
    image: rbcbj/nexus-gate:main
    command: |
      -a 10.6.0.1/24
      -b 51820
      -e <the address endpoint of server to be used in clients>
      -p "user;10.6.0.2/32"
      -s 'google;google.internal;https://google.com'
    cap_add:
      - NET_ADMIN
    ports:
      - "51820:51820/udp"
    volumes:
      - ./config:/var/lib/wg/
```

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