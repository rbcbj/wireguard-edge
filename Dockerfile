ARG BASE_IMAGE=ubuntu:24.04
ARG IMAGE_PLATFORM=linux/amd64
FROM --platform=$IMAGE_PLATFORM $BASE_IMAGE
MAINTAINER Robson Jr "http://robsonjr.com.br"

ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=Etc/UTC
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

RUN apt-get update \
  && apt-get install -y --no-install-recommends \
    wireguard \
    iproute2 iptables \
    procps net-tools \
    curl gnupg \
    vim \
    `# separator` \
    jq \
    `# separator` \
    nginx \
    supervisor \
    gettext-base `# envsubst` \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/*

# forward request and error logs to docker log collector
RUN ln -sf /dev/stdout /var/log/nginx/access.log \
  && ln -sf /dev/stderr /var/log/nginx/error.log

ADD assets/etc                 /etc
ADD assets/docker-entrypoint.d /docker-entrypoint.d
ADD assets/usr                 /usr

EXPOSE 51820

VOLUME ["/var/lib/wg"]

ENTRYPOINT ["/docker-entrypoint.d/docker-entrypoint.sh"]