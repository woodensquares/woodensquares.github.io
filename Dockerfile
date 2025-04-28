FROM ubuntu:latest
SHELL ["/bin/bash", "-c"]
LABEL authors="woodensquares"
ARG HUGO_VERSION=0.145.0

USER root
RUN apt-get update && apt-get install -y wget
RUN wget https://github.com/sass/dart-sass/releases/download/1.87.0/dart-sass-1.87.0-linux-x64.tar.gz && tar xf dart-sass-1.87.0-linux-x64.tar.gz && mv dart-sass/* /usr/bin/
RUN wget -O ./hugo.deb https://github.com/gohugoio/hugo/releases/download/v${HUGO_VERSION}/hugo_extended_${HUGO_VERSION}_linux-amd64.deb \
          && dpkg -i ./hugo.deb
USER ubuntu
RUN mkdir /home/ubuntu/hugo

USER ubuntu:ubuntu
VOLUME /home/ubuntu
WORKDIR /home/ubuntu
EXPOSE 8188
CMD ["/home/ubuntu/entrypoint.sh"]

STOPSIGNAL SIGTERM
