FROM alpine:3.4
MAINTAINER Kevin Cantwell <kevin.cantwell@gmail.com>

RUN apk -v --update add \
  bash \
  ca-certificates \
  python \
  py-pip \
  groff \
  less \
  mailcap \
  && \
  pip install --upgrade awscli s3cmd python-magic && \
  apk -v --purge del py-pip && \
  rm /var/cache/apk/*

ADD . /docker-cloud-startup
WORKDIR /docker-cloud-startup
CMD ./cfn-create-stack.sh