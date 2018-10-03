FROM ubuntu:18.04

RUN apt-get update \
    && apt-get install -y --no-install-recommends apt-transport-https \
               ca-certificates curl software-properties-common gnupg dirmngr \
    && apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 9DC858229FC7DD38854AE2D88D81803C0EBFCD88 \
    && add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
                          $(lsb_release -cs) stable" \
    && apt-get update \
    && apt-get install -y --no-install-recommends ufw "docker-ce=18.06.1~*" \
    && apt-get clean autoclean \
    && apt-get autoremove --yes \
    && rm -rf /var/lib/{apt,dpkg,cache,log}/

ADD ufw-docker docker-entrypoint.sh /usr/bin/

ENTRYPOINT ["/usr/bin/docker-entrypoint.sh"]

CMD ["start"]
