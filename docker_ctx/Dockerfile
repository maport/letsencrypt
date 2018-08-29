FROM ubuntu:16.04
MAINTAINER Michael Porter <mike@codesimple.net>

RUN apt-get update \
    && apt-get install -y software-properties-common \
    && add-apt-repository ppa:certbot/certbot \
    && apt-get update \
    && apt-get install -y \
    certbot=0.26.1-1+ubuntu16.04.1+certbot+2 \
    curl \
    git \
    python-pip

RUN pip install 'git+https://gitlab.com/cspublic/certbot-plugin-gandi.git'

RUN certbot --help
