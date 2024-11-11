FROM ubuntu:24.04

ARG docker_version="27.3.1"

ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update \
    && apt-get install -y ca-certificates curl gnupg lsb-release \
    && mkdir -p /etc/apt/keyrings \
    && curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg]" \
            "https://download.docker.com/linux/ubuntu" "$(lsb_release -cs) stable" \
            | tee /etc/apt/sources.list.d/docker.list > /dev/null \
    && apt-get update \
    && apt-get install -y --no-install-recommends locales ufw \
    && apt-get install -y --no-install-recommends "docker-ce=$(apt-cache madison docker-ce | grep -m1 -F "${docker_version}" | cut -d'|' -f2 | tr -d '[[:blank:]]')" \
    && locale-gen en_US.UTF-8 \
    && apt-get clean autoclean \
    && apt-get autoremove --yes \
    && rm -rf /var/lib/{apt,dpkg,cache,log}/

ADD ufw-docker docker-entrypoint.sh /usr/bin/

ENTRYPOINT ["/usr/bin/docker-entrypoint.sh"]

CMD ["start"]

ADD LICENSE README.md /
