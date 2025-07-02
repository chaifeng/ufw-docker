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
  ip6_prefix="fd00:a:b"
  worker_count=1

  def env_true?(env_name)
    value = ENV[env_name] || 'false'
    true_values  = %w[true yes on 1]
    down = value.strip.downcase
    return 'true' if true_values.include?(down)
    'false'
  end

  def env_true_str?(env_name)
    env_true?(env_name).to_s
  end

  config.vm.provision 'setup', preserve_order: true, type: 'shell', privileged: false, inline: <<-SHELL
    byobu-ctrl-a screen
  SHELL

  config.vm.provision 'docker-daemon-config',  type: 'shell', inline: <<-SHELL
    set -eu
    [[ -f /etc/profile.d/editor.sh ]] || echo 'export EDITOR=vim' > /etc/profile.d/editor.sh
    if [[ "$(hostname)" = @(master|node?) && ! -f /etc/docker/daemon.json ]]; then
      echo '{' >> /etc/docker/daemon.json
      echo '  "insecure-registries": ["localhost:5000", "#{ip_prefix}.130:5000"]' >> /etc/docker/daemon.json
      [[ -n "#{ENV['DOCKER_REGISTRY_MIRROR']}" ]] &&
        echo '  , "registry-mirrors": ["#{ENV['DOCKER_REGISTRY_MIRROR']}"]' >> /etc/docker/daemon.json
      #{env_true_str?('ENABLE_DOCKER_IPV6')} &&
       echo '  ,"ip6tables": true, "ipv6": true, "fixed-cidr-v6": "#{ip6_prefix}:deaf::/64"' >> /etc/docker/daemon.json
      echo '}' >> /etc/docker/daemon.json
      if type systemctl &>/dev/null; then
        systemctl restart docker
      else
        service docker restart
      fi
    fi
  SHELL

  config.vm.provision 'ufw-docker', preserve_order: true, type: 'shell', inline: <<-SHELL
    set -xeuo pipefail
    export DEBUG=true
    lsb_release -is | grep -Fi ubuntu

    declare -a subnets=(--docker-subnets 192.168.56.128/28 10.0.0.0/8 172.16.0.0/12)
    #{env_true_str?('ENABLE_DOCKER_IPV6')} &&
      subnets+=(fd00:a:b:deaf::/64 fd05:8f23:c937:1::/64 fd05:8f23:c937:2::/64 fd05:8f23:c937::/64)
    if [[ "$(hostname)" = @(master|node?) ]]; then
      /vagrant/ufw-docker check "${subnets[@]-}" >/dev/null 2>&1 || {
        ufw allow OpenSSH
        ufw allow from #{ip_prefix}.128/28 to any
        #{env_true_str?('ENABLE_DOCKER_IPV6')} &&
          ufw allow from #{ip6_prefix}:0:cafe::/80 to any

        yes | ufw enable || true
        ufw status | grep '^Status: active'

        /vagrant/ufw-docker install "${subnets[@]-}"

        systemctl restart ufw
      }
      [[ -L /usr/local/bin/ufw-docker ]] || ln -s /vagrant/ufw-docker /usr/local/bin/
    fi
  SHELL

  private_registry="#{ip_prefix}.130:5000"

  config.vm.define "master" do |master|
    master_ip_address = "#{ip_prefix}.130"
    master.vm.hostname = "master"
    master.vm.network "private_network", ip: "#{master_ip_address}"
    if env_true?('ENABLE_DOCKER_IPV6')
      master.vm.network "private_network", ip: "#{ip6_prefix}:0:cafe::130", type: "static", netmast: 64, auto_config: true
    end

    master.vm.provision "unit-testing", preserve_order: true, type: 'shell', privileged: false, inline: <<-SHELL
        set -euo pipefail
        [[ -n "#{ENV['DISABLE_UNIT_TESTING']}" ]] ||
           /vagrant/test.sh
    SHELL

    master.vm.provision "docker-registry", preserve_order: true, type: 'docker' do |d|
      d.run "registry",
            image: "registry:2",
            args: "-p 5000:5000",
            restart: "always",
            daemonize: true
    end

    ufw_docker_agent_image = "#{private_registry}/chaifeng/ufw-docker-agent:test"

    master.vm.provision "docker-build-ufw-docker-agent", preserve_order: true, type: 'shell', inline: <<-SHELL
      set -xeuo pipefail
      suffix="$(iptables --version | grep -o '\\(nf_tables\\|legacy\\)')"
      if [[ "$suffix" = legacy ]]; then use_iptables_legacy=true; else use_iptables_legacy=false; fi
      docker build --build-arg use_iptables_legacy="${use_iptables_legacy:-false}" -t "#{ufw_docker_agent_image}-${suffix}" /vagrant
      docker push "#{ufw_docker_agent_image}-${suffix}"

      echo "export UFW_DOCKER_AGENT_IMAGE=#{ufw_docker_agent_image}-${suffix}" > /etc/profile.d/ufw-docker.sh
      echo "export DEBUG=true" >> /etc/profile.d/ufw-docker.sh

      echo "Defaults env_keep += UFW_DOCKER_AGENT_IMAGE" > /etc/sudoers.d/98_ufw-docker
      echo "Defaults env_keep += DEBUG" >> /etc/sudoers.d/98_ufw-docker
    SHELL

    master.vm.provision "swarm-init", preserve_order: true, type: 'shell', privileged: false, inline: <<-SHELL
      set -euo pipefail
      docker info | fgrep 'Swarm: active' && exit 0

      docker swarm init --advertise-addr "#{master_ip_address}"
      docker swarm join-token worker --quiet > /vagrant/.vagrant/docker-join-token
    SHELL

    master.vm.provision "build-webapp", preserve_order: true, type: 'shell', privileged: false, inline: <<-SHELL
        set -xeuo pipefail
        docker build -t #{private_registry}/chaifeng/hostname-webapp - <<\\DOCKERFILE
FROM httpd:alpine

RUN printf "Listen %s\\n" 7000 8080 >> /usr/local/apache2/conf/httpd.conf

RUN { echo '#!/bin/sh'; \\
    echo 'set -e; (echo -n "${name:-Hi} "; hostname;) > /usr/local/apache2/htdocs/index.html'; \\
    echo 'exec "$@"'; \\
    } > /entrypoint.sh; chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
CMD ["httpd-foreground"]
DOCKERFILE
        docker push #{private_registry}/chaifeng/hostname-webapp
    SHELL

    master.vm.provision "local-webapp", preserve_order: true, type: 'shell', inline: <<-SHELL
        set -xeuo pipefail
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
      set -xeuo pipefail
      declare -a docker_opts=()

      if ! docker network ls | grep -F foo-internal; then
          ! #{env_true_str?('ENABLE_DOCKER_IPV6')} || docker_opts=(--ipv6 --subnet fd05:8f23:c937:1::/64)
          docker network create --internal "${docker_opts[@]}" foo-internal
      fi
      if ! docker network ls | grep -F bar-external; then
          ! #{env_true_str?('ENABLE_DOCKER_IPV6')} || docker_opts=(--ipv6 --subnet fd05:8f23:c937:2::/64)
          docker network create "${docker_opts[@]}" bar-external
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
        set -xeuo pipefail
        declare -a docker_opts=()
        if #{env_true_str?('ENABLE_DOCKER_IPV6')}; then
            docker inspect ip6net >/dev/null ||
               docker network create --driver overlay --ipv6 ip6net
            docker_opts+=(--network ip6net)
        fi
        for name in public:29090 local:9000; do
            webapp="${name%:*}_service"
            port="${name#*:}"
            if docker service inspect "$webapp" &>/dev/null; then docker service rm "$webapp"; fi
            docker service create --name "$webapp" "${docker_opts[@]}" \
                --publish "${port}:80" --env name="$webapp" --replicas #{worker_count} #{private_registry}/chaifeng/hostname-webapp
        done

        ufw-docker service allow public_service 80/tcp

        docker service inspect "public_multiport" ||
            docker service create --name "public_multiport" "${docker_opts[@]}" \
                --publish "40080:80" --publish "47000:7000" --publish "48080:8080" \
                --env name="public_multiport" --replicas #{worker_count + 1} #{private_registry}/chaifeng/hostname-webapp

        ufw-docker service allow public_multiport 80/tcp
        ufw-docker service allow public_multiport 8080/tcp
    SHELL
  end

  1.upto worker_count do |ip|
    config.vm.define "node#{ip}" do | node |
      node.vm.hostname = "node#{ip}"
      node.vm.network "private_network", ip: "#{ip_prefix}.#{ 130 + ip }"
      if env_true?('ENABLE_DOCKER_IPV6')
        node.vm.network "private_network", ip: "#{ip6_prefix}:0:cafe::#{ 130 + ip }", type: "static", netmast: 64, auto_config: true
      end

      node.vm.provision "node#{ip}-swarm-join", preserve_order: true, type: 'shell', inline: <<-SHELL
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
    if env_true?('ENABLE_DOCKER_IPV6')
      node.vm.network "private_network", ip: "#{ip6_prefix}:0:cafe::142", type: "static", netmast: 64, auto_config: true
    end
  end

  config.vm.define "external" do |external|
    external.vm.hostname = "external"
    external.vm.network "private_network", ip: "#{ip_prefix}.127"
    if env_true?('ENABLE_DOCKER_IPV6')
      external.vm.network "private_network", ip: "#{ip6_prefix}:0:eeee::127", type: "static", netmast: 64, auto_config: true
    end

    external.vm.provision "testing", preserve_order: true, type: 'shell', privileged: false, inline: <<-SHELL
        set -xuo pipefail
        error_count=0
        function test-webapp() {
          local actual=""

          if [[ "$#" -eq 2 ]]; then
            local expect_fail='!'
            url="$2"
          else
            url="$1"
          fi

          timeout 3 curl --silent "$url" || actual='!'

          if [[ "${expect_fail:-}" = "${actual}" ]]; then
            echo "OK: '$url' is ${expect_fail:+NOT }accessible${expect_fail:+ (should NOT be)}."
          else
            echo "FAIL: '$url' is ${expect_fail:+}${expect_fail:-NOT }accessible${expect_fail:-}."
            (( ++ error_count ))
            return 1
          fi
        } 2>/dev/null

        function run_tests() {
          local server="$1"
          test-webapp "$server:18080"
          test-webapp ! "$server:8000"

          test-webapp "$server:17070" # multiple networks app
          test-webapp ! "$server:7000" # internal multiple networks app

          # Docker Swarm
          test-webapp ! "$server:9000"
          test-webapp ! "$server:47000"
        }
        function run_tests_ipv4() {
          local server="$1"
          # Docker Swarm
          test-webapp "$server:29090"

          test-webapp "$server:40080"
          test-webapp "$server:48080"

        }
        function run_tests_ipv6() {
          local server="$1"

          echo TODO: It seems that Docker Swarm does not support IPv6 well >&2

          test-webapp ! "$server:29090" # it is accessible via IPv4
          test-webapp ! "$server:40080" # it is accessible via IPv4
          test-webapp ! "$server:48080" # it is accessible via IPv4

        }

        run_tests "http://#{ip_prefix}.130"
        run_tests_ipv4 "http://#{ip_prefix}.130"

        if #{env_true_str?('ENABLE_DOCKER_IPV6')}; then
          run_tests "http://[#{ip6_prefix}:0:cafe::130]"
          run_tests_ipv6 "http://[#{ip6_prefix}:0:cafe::130]"
        fi
        {
        echo "====================="
        if [[ "$error_count" -eq 0 ]]; then echo "      TEST DONE      "
        else echo "   TESTS FAIL: ${error_count}"
        fi
        echo "====================="
        exit "${error_count}"
        } 2>/dev/null
    SHELL
  end
end
