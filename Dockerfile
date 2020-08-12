FROM ubuntu:20.04

ARG docker_version="19.03.12"

ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update \
    && apt-get install -y --no-install-recommends apt-transport-https \
               ca-certificates curl software-properties-common gnupg dirmngr \
    && apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 9DC858229FC7DD38854AE2D88D81803C0EBFCD88 \
    && add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
                          $(lsb_release -cs) stable" \
    && apt-get update \
    && apt-get install -y --no-install-recommends locales ufw \
    && ( apt-get install -y --no-install-recommends "docker-ce=5:${docker_version}~*" || \
         apt-get install -y --no-install-recommends "docker-ce=${docker_version}~*" ) \
    && locale-gen en_US.UTF-8 \
    && apt-get clean autoclean \
    && apt-get autoremove --yes \
    && rm -rf /var/lib/{apt,dpkg,cache,log}/

ADD ufw-docker docker-entrypoint.sh /usr/bin/

ENTRYPOINT ["/usr/bin/docker-entrypoint.sh"]

CMD ["start"]

ADD LICENSE README.md /
