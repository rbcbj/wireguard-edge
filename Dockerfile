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

RUN rm /etc/nginx/sites-enabled/default

ADD assets/etc                 /etc
ADD assets/docker-entrypoint.d /docker-entrypoint.d
ADD assets/usr                 /usr

EXPOSE 51820

VOLUME ["/var/lib/wg"]

ENTRYPOINT ["/docker-entrypoint.d/docker-entrypoint.sh"]