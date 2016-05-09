FROM ubuntu:trusty-20160503.1
MAINTAINER Michael Porter <mike@codesimple.net>

RUN apt-get update && apt-get install -y \
    wget

RUN mkdir /code

ARG LE_VERSION=0.5.0

RUN wget --output-document=- "https://github.com/certbot/certbot/archive/v${LE_VERSION}.tar.gz" \
    | tar --extract --gzip --directory '/code' \
    && cd "/code/certbot-${LE_VERSION}" \
    && ./letsencrypt-auto --help

WORKDIR "/code/certbot-${LE_VERSION}" 
