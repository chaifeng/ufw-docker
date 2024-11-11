# frozen_string_literal: true

# -*- mode: ruby -*-
# vi: set ft=ruby :

ENV['VAGRANT_NO_PARALLEL']="true"

Vagrant.configure('2') do |config|
  ubuntu_version = File.readlines("Dockerfile").filter { |line|
    line.start_with?("FROM ")
  }.first.match(/\d\d\.\d\d/)[0]

  docker_version = File.readlines("Dockerfile").filter { |line|
    line.start_with?("ARG docker_version=")
  }.first.match(/"([\d\.]+)"/)[1]

  config.vm.box = "chaifeng/ubuntu-#{ubuntu_version}-docker-#{docker_version}"

  config.vm.provider 'virtualbox' do |vb|
    vb.memory = '1024'
    vb.default_nic_type = "virtio"
  end

  config.vm.provider 'parallels' do |prl|
    prl.memory = '1024'
    prl.check_guest_tools = false
  end

  ip_prefix="192.168.56"

  config.vm.provision 'docker-daemon-config', type: 'shell', inline: <<-SHELL
    set -eu
    if [[ ! -f /etc/docker/daemon.json ]]; then
      echo '{' >> /etc/docker/daemon.json
      echo '  "insecure-registries": ["localhost:5000", "#{ip_prefix}.130:5000"]' >> /etc/docker/daemon.json
      [[ -n "#{ENV['DOCKER_REGISTRY_MIRROR']}" ]] &&
        echo '  , "registry-mirrors": ["#{ENV['DOCKER_REGISTRY_MIRROR']}"]' >> /etc/docker/daemon.json
      echo '}' >> /etc/docker/daemon.json
      if type systemctl &>/dev/null; then
        systemctl restart docker
      else
        service docker restart
      fi
    fi
  SHELL

  config.vm.provision 'ufw-docker', type: 'shell', inline: <<-SHELL
    set -euo pipefail
    export DEBUG=true
    lsb_release -is | grep -Fi ubuntu
    /vagrant/ufw-docker check || {
      ufw allow OpenSSH
      ufw allow from #{ip_prefix}.128/28 to any

      yes | ufw enable || true
      ufw status | grep '^Status: active'

      /vagrant/ufw-docker install

      sed -i -e 's,192\.168\.0\.0/16,#{ip_prefix}.128/28,' /etc/ufw/after.rules

      systemctl restart ufw

      [[ -L /usr/local/bin/ufw-docker ]] || ln -s /vagrant/ufw-docker /usr/local/bin/

      iptables -I DOCKER-USER 4 -p udp -j LOG --log-prefix '[UFW DOCKER] '
    }
  SHELL

  private_registry="#{ip_prefix}.130:5000"

  config.vm.define "master" do |master|
    master_ip_address = "#{ip_prefix}.130"
    master.vm.hostname = "master"
    master.vm.network "private_network", ip: "#{master_ip_address}"

    master.vm.provision "unit-testing", preserve_order: true, type: 'shell', inline: <<-SHELL
        set -euo pipefail
        /vagrant/test.sh
    SHELL

    master.vm.provision "docker-registry", preserve_order: true, type: 'docker' do |d|
      d.run "registry",
            image: "registry:2",
            args: "-p 5000:5000",
            restart: "always",
            daemonize: true
    end

    ufw_docker_agent_image = "#{private_registry}/chaifeng/ufw-docker-agent:test-legacy"

    master.vm.provision "docker-build-ufw-docker-agent", preserve_order: true, type: 'shell', inline: <<-SHELL
      set -euo pipefail
      suffix="$(iptables --version | grep -o '\\(nf_tables\\|legacy\\)')"
      docker build -t "#{ufw_docker_agent_image}-${suffix}" /vagrant
      docker push "#{ufw_docker_agent_image}-${suffix}"

      echo "export UFW_DOCKER_AGENT_IMAGE=#{ufw_docker_agent_image}-${suffix}" > /etc/profile.d/ufw-docker.sh
      echo "export DEBUG=true" >> /etc/profile.d/ufw-docker.sh

      echo "Defaults env_keep += UFW_DOCKER_AGENT_IMAGE" > /etc/sudoers.d/98_ufw-docker
      echo "Defaults env_keep += DEBUG" >> /etc/sudoers.d/98_ufw-docker
    SHELL

    master.vm.provision "swarm-init", preserve_order: true, type: 'shell', inline: <<-SHELL
      set -euo pipefail
      docker info | fgrep 'Swarm: active' && exit 0

      docker swarm init --advertise-addr "#{master_ip_address}"
      docker swarm join-token worker --quiet > /vagrant/.vagrant/docker-join-token
    SHELL

    master.vm.provision "build-webapp", preserve_order: true, type: 'shell', inline: <<-SHELL
        set -euo pipefail
        docker build -t #{private_registry}/chaifeng/hostname-webapp - <<\\DOCKERFILE
FROM httpd:alpine

RUN { echo '#!/bin/sh'; \\
    echo 'set -e; (echo -n "${name:-Hi} "; hostname;) > /usr/local/apache2/htdocs/index.html'; \\
    echo 'grep "^Listen 7000" || echo Listen 7000 >> /usr/local/apache2/conf/httpd.conf'; \\
    echo 'grep "^Listen 8080" || echo Listen 8080 >> /usr/local/apache2/conf/httpd.conf'; \\
    echo 'exec "$@"'; \\
    } > /entrypoint.sh; chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
CMD ["httpd-foreground"]
DOCKERFILE
        docker push #{private_registry}/chaifeng/hostname-webapp
    SHELL

    master.vm.provision "local-webapp", preserve_order: true, type: 'shell', inline: <<-SHELL
        set -euo pipefail
        for name in public:18080 local:8000; do
            webapp="${name%:*}_webapp"
            port="${name#*:}"
            if docker inspect "$webapp" &>/dev/null; then docker rm -f "$webapp"; fi
            docker run -d --restart unless-stopped --name "$webapp" \
                -p "$port:80" --env name="$webapp" #{private_registry}/chaifeng/hostname-webapp
            sleep 1
        done

        ufw-docker allow public_webapp
    SHELL

    master.vm.provision "multiple-network", preserve_order: true, type: 'shell', inline: <<-SHELL
      set -euo pipefail
      if ! docker network ls | grep -F foo-internal; then
          docker network create --internal foo-internal
      fi
      if ! docker network ls | grep -F bar-external; then
          docker network create bar-external
      fi

      for app in internal-multinet-app:7000 public-multinet-app:17070; do
          if ! docker inspect "${app%:*}" &>/dev/null; then
              docker run -d --restart unless-stopped --name "${app%:*}" \
                         -p "${app#*:}":80 --env name="${app}" \
                         --network foo-internal \
                         192.168.56.130:5000/chaifeng/hostname-webapp
              docker network connect bar-external "${app%:*}"
          fi
      done

      ufw-docker allow public-multinet-app 80 bar-external
      ufw-docker allow internal-multinet-app 80 foo-internal
    SHELL

    master.vm.provision "swarm-webapp", preserve_order: true, type: 'shell', inline: <<-SHELL
      set -euo pipefail
        for name in public:29090 local:9000; do
            webapp="${name%:*}_service"
            port="${name#*:}"
            if docker service inspect "$webapp" &>/dev/null; then docker service rm "$webapp"; fi
            docker service create --name "$webapp" \
                --publish "${port}:80" --env name="$webapp" --replicas 3 #{private_registry}/chaifeng/hostname-webapp
        done

        ufw-docker service allow public_service 80/tcp

        docker service inspect "public_multiport" ||
            docker service create --name "public_multiport" \
                --publish "40080:80" --publish "47000:7000" --publish "48080:8080" \
                --env name="public_multiport" --replicas 3 #{private_registry}/chaifeng/hostname-webapp

        ufw-docker service allow public_multiport 80/tcp
        ufw-docker service allow public_multiport 8080/tcp
    SHELL
  end

  1.upto 2 do |ip|
    config.vm.define "node#{ip}" do | node |
      node.vm.hostname = "node#{ip}"
      node.vm.network "private_network", ip: "#{ip_prefix}.#{ 130 + ip }"

      node.vm.provision "swarm-join", preserve_order: true, type: 'shell', inline: <<-SHELL
        set -euo pipefail
        docker info | fgrep 'Swarm: active' && exit 0

        [[ -f /vagrant/.vagrant/docker-join-token ]] &&
        docker swarm join --token "$(</vagrant/.vagrant/docker-join-token)" #{ip_prefix}.130:2377
      SHELL
    end
  end

  config.vm.define "node-internal" do |node|
    node.vm.hostname = "node-internal"
    node.vm.network "private_network", ip: "#{ip_prefix}.142"
  end

  config.vm.define "external" do |external|
    external.vm.hostname = "external"
    external.vm.network "private_network", ip: "#{ip_prefix}.127"

    external.vm.provision "testing", preserve_order: true, type: 'shell', inline: <<-SHELL
        set -euo pipefail
        set -x
        server="http://#{ip_prefix}.130"
        function test-webapp() {
          if timeout 3 curl --silent "$@"
          then echo "Success: $*"
          else echo "Cannot visit: $*"; return 1
          fi
        }
        test-webapp "$server:18080"
        ! test-webapp "$server:8000"

        test-webapp "$server:17070" # multiple networks app
        ! test-webapp "$server:7000" # internal multiple networks app

        test-webapp "$server:29090"
        ! test-webapp "$server:9000"

        test-webapp "$server:40080"
        test-webapp "$server:48080"
        ! test-webapp "$server:47000"

        echo "====================="
        echo "      TEST DONE      "
        echo "====================="
    SHELL
  end
end
