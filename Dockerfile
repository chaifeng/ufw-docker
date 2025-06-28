FROM ubuntu:24.04

ARG docker_version="27.3.1"
ARG use_iptables_legacy=false

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
    && if "$use_iptables_legacy"; then \
          apt-get -y install arptables ebtables \
          && update-alternatives --install /usr/sbin/arptables arptables /usr/sbin/arptables-legacy 100 \
          && update-alternatives --install /usr/sbin/ebtables ebtables /usr/sbin/ebtables-legacy 100 \
          && update-alternatives --set iptables /usr/sbin/iptables-legacy \
          && update-alternatives --set ip6tables /usr/sbin/ip6tables-legacy \
          && update-alternatives --set arptables /usr/sbin/arptables-legacy \
          && update-alternatives --set ebtables /usr/sbin/ebtables-legacy; \
       fi \
    && apt-get clean autoclean \
    && apt-get autoremove --yes \
    && rm -rf /var/lib/{apt,dpkg,cache,log}/

ADD ufw-docker docker-entrypoint.sh /usr/bin/

ENTRYPOINT ["/usr/bin/docker-entrypoint.sh"]

CMD ["start"]

ADD LICENSE README.md /
