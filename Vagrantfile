# frozen_string_literal: true

# -*- mode: ruby -*-
# vi: set ft=ruby :

ENV['VAGRANT_NO_PARALLEL']="true"

Vagrant.configure('2') do |config|
  dockerfile_path = File.expand_path("Dockerfile", __dir__)
  
  ubuntu_version = File.readlines(dockerfile_path).filter { |line|
    line.start_with?("FROM ")
  }.first.match(/\d\d\.\d\d/)[0]

  docker_version = File.readlines(dockerfile_path).filter { |line|
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
  worker_count=2

  def env_true?(env_name)
    value = ENV[env_name] || 'false'
    true_values  = %w[true yes on 1 y]
    down = value.strip.downcase
    return 'true' if true_values.include?(down)
    'false'
  end

  def env_true_str?(env_name)
    env_true?(env_name).to_s
  end

  config.vm.provision 'shell', preserve_order: true, run: 'once', privileged: false, inline: <<-SHELL
    byobu-ctrl-a screen
  SHELL

  config.vm.provision 'shell', preserve_order: true, run: 'once', privileged: true, inline: <<-SHELL
    [[ -f /etc/profile.d/editor.sh ]] || echo 'export EDITOR=vim' > /etc/profile.d/editor.sh

    if [ -f /etc/ufw-docker-iptables-setup-done ]; then
      exit 0
    fi

    if #{env_true_str?('USE_IPTABLES_LEGACY')}; then
      echo "Using legacy iptables"
      # switch to legacy iptables
      update-alternatives --set iptables /usr/sbin/iptables-legacy
      update-alternatives --set ip6tables /usr/sbin/ip6tables-legacy
      nft flush ruleset || true
    else
      echo "Using nf_tables"
      # switch to nf_tables
      update-alternatives --set iptables /usr/sbin/iptables-nft
      update-alternatives --set ip6tables /usr/sbin/ip6tables-nft
      
      # Flush legacy rules
      for table in filter nat mangle raw; do
        iptables-legacy -t $table -F || true
        iptables-legacy -t $table -X || true
        ip6tables-legacy -t $table -F || true
        ip6tables-legacy -t $table -X || true
      done
    fi

    touch /etc/ufw-docker-iptables-setup-done
  SHELL

  config.vm.provision 'docker-daemon-config', preserve_order: true, type: 'shell', inline: <<-SHELL
    set -eu
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
        "#{env_true_str?('DISABLE_UNIT_TESTING')}" || /vagrant/test.sh
    SHELL

    master.vm.provision "docker-registry", preserve_order: true, type: 'docker' do |d|
      d.run "docker_registry",
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

RUN apk add --no-cache socat curl
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

    master.vm.provision "test-cases-setup", preserve_order: true, type: 'shell', inline: <<-SHELL
        set -xeuo pipefail

        # UDP Test Setup
        if docker inspect udp_echo_test &>/dev/null; then docker rm -f udp_echo_test; fi
        docker run -d --restart unless-stopped --name udp_echo_test \
            -p 30000:30000/udp #{private_registry}/chaifeng/hostname-webapp \
            sh -c 'socat UDP6-LISTEN:30000,fork EXEC:cat & socat UDP-LISTEN:30000,fork EXEC:cat & wait'

        ufw-docker allow udp_echo_test 30000/udp

        # UDP Deny Test Setup
        if docker inspect udp_deny_test &>/dev/null; then docker rm -f udp_deny_test; fi
        docker run -d --restart unless-stopped --name udp_deny_test \
            -p 30001:30000/udp #{private_registry}/chaifeng/hostname-webapp \
            sh -c 'socat UDP6-LISTEN:30000,fork EXEC:cat & socat UDP-LISTEN:30000,fork EXEC:cat & wait'

        # Delete Rule Test Setup
        if docker inspect deleted_webapp_test &>/dev/null; then docker rm -f deleted_webapp_test; fi
        docker run -d --restart unless-stopped --name deleted_webapp_test \
            -p 18081:80 --env name="deleted_webapp_test" #{private_registry}/chaifeng/hostname-webapp

        ufw-docker allow deleted_webapp_test
        ufw-docker delete allow deleted_webapp_test
    SHELL

    master.vm.provision "multiple-network", preserve_order: true, type: 'shell', inline: <<-SHELL
      set -xeuo pipefail
      declare -a docker_opts=()

      if ! docker network ls | grep -F foo_internal_network; then
          ! #{env_true_str?('ENABLE_DOCKER_IPV6')} || docker_opts=(--ipv6 --subnet fd05:8f23:c937:1::/64)
          docker network create --internal "${docker_opts[@]}" foo_internal_network
      fi
      if ! docker network ls | grep -F bar_external_network; then
          ! #{env_true_str?('ENABLE_DOCKER_IPV6')} || docker_opts=(--ipv6 --subnet fd05:8f23:c937:2::/64)
          docker network create "${docker_opts[@]}" bar_external_network
      fi

      for app in internal_multinet_app:7000 public_multinet_app:17070; do
          if ! docker inspect "${app%:*}" &>/dev/null; then
              docker run -d --restart unless-stopped --name "${app%:*}" \
                         -p "${app#*:}":80 --env name="${app}" \
                         --network foo_internal_network \
                         192.168.56.130:5000/chaifeng/hostname-webapp
              docker network connect bar_external_network "${app%:*}"
          fi
      done

      ufw-docker allow public_multinet_app 80 bar_external_network
      ufw-docker allow internal_multinet_app 80 foo_internal_network
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

        # --- New Overlay Network Test Setup ---
        if ! docker network ls | grep -F test_overlay_network; then
            docker network create --driver overlay test_overlay_network
        fi

        # Service A: 8080->80 (Allow), 8081->8080 (Block)
        if docker service inspect test_service_a &>/dev/null; then docker service rm test_service_a; fi
        docker service create --name test_service_a --network test_overlay_network \
            --publish 8080:80 --publish 8081:8080 \
            --env name="test_service_a" --replicas 1 \
            #{private_registry}/chaifeng/hostname-webapp

        ufw-docker service allow test_service_a 80/tcp
        # 8081 is not allowed, so it should be blocked by default

        # Service B: 9090->80 (Allow), 9091->8080 (Block)
        if docker service inspect test_service_b &>/dev/null; then docker service rm test_service_b; fi
        docker service create --name test_service_b --network test_overlay_network \
            --publish 9090:80 --publish 9091:8080 \
            --env name="test_service_b" --replicas 1 \
            #{private_registry}/chaifeng/hostname-webapp

        ufw-docker service allow test_service_b 80/tcp
        # 9091 is not allowed, so it should be blocked by default
    SHELL

    TEST_WEBAPP_SCRIPT = <<~SHELL
      exec 8>&2
      BASH_XTRACEFD=8
      export error_count=0

      function test-webapp() {
        local expect_success=""
        local src_container
        declare -a args=()
        while [[ -n "${1:-}" ]]; do
          case "$1" in
            '!') expect_success='!' ;;
            '--container') shift; src_container="${1}" ;;
            *) args+=("$1") ;;
          esac
          shift
        done
        set -- "${args[@]}"
        local target_url="${1}"
        
        echo "Testing connection from ${src_container:+container} ${src_container:-HOST} to $target_url (Expect $(if [ "$expect_success" = "!" ]; then echo -n "failure"; else echo -n "success"; fi))"
        
        declare -a cmd=(command)
        [[ -z "${src_container:-}" ]] || cmd=(docker exec "$src_container")
        cmd+=(curl -m 2 -v -o /dev/null "$target_url")
        if "${cmd[@]}"; then
          if [ "$expect_success" = "!" ]; then
            echo "❌ FAILURE: Connection established but should have failed."
            error_count=$(( error_count + 1 ))
          else
            echo "✅ SUCCESS: Connection established."
          fi
        else
          if [ "$expect_success" = "!" ]; then
            echo "✅ SUCCESS: Connection failed as expected."
          else
            echo "❌ FAILURE: Connection failed."
            error_count=$(( error_count + 1 ))
          fi
        fi
      } 8>/dev/null

      function test-udp() {
        local expect_fail="${1}"
        if [[ "$expect_fail" == "!" ]]; then
          shift
        else
          expect_fail=""
        fi
        local host="$1"
        # Remove brackets for IPv6
        host="${host#[}"
        host="${host%]}"
        local port="$2"
        local payload="udp-test"
        local response
        
        response=$(echo -n "$payload" | nc -u -w 1 "$host" "$port" 2>/dev/null || true)
        
        if [[ "$response" == "$payload" ]]; then
          if [[ "$expect_fail" == "!" ]]; then
            echo "FAIL: UDP $host:$port IS accessible (should NOT be)."
            (( ++ error_count ))
          else
            echo "OK: UDP $host:$port is accessible."
          fi
        else
          if [[ "$expect_fail" == "!" ]]; then
            echo "OK: UDP $host:$port is NOT accessible."
          else
            echo "FAIL: UDP $host:$port is NOT accessible (expected '$payload', got '$response')."
            (( ++ error_count ))
          fi
        fi
      } 8>/dev/null
    SHELL

    TEST_WEBAPP_RESULT = <<~SHELL
      {
        echo ""
        echo "========================================="
        if [[ "$error_count" -eq 0 ]]; then
          echo "====  ✅ SUCCESS: All tests passed.  ===="
        else 
          echo "====   ❌ FAILURE: $error_count tests failed.   ===="
        fi
        echo "========================================="
        echo ""
      } 8>/dev/null
      exit "$error_count"
    SHELL

    master.vm.provision "test-container-communication", preserve_order: true, type: 'shell', inline: <<-SHELL
      set -xeuo pipefail
      #{TEST_WEBAPP_SCRIPT}

      test-webapp --container "internal_multinet_app" "http://public_multinet_app:80"

      # get the ip address of public_webapp
      public_webapp_ip=$(docker inspect public_webapp | jq -r '.[0].NetworkSettings.Networks."bridge".IPAddress')
      test-webapp ! --container "internal_multinet_app" "http://$public_webapp_ip:80" # Should fail (different networks)

      # get the ip address of local_webapp
      local_webapp_ip=$(docker inspect local_webapp | jq -r '.[0].NetworkSettings.Networks."bridge".IPAddress')
      test-webapp --container "public_webapp" "http://$local_webapp_ip:80"
      
      # --- New Overlay Network Verification ---
      echo "=== Verifying Overlay Network Services ==="
      
      test-webapp "http://#{ip_prefix}.130:8080" # Should succeed (Internal traffic allowed)
      test-webapp "http://#{ip_prefix}.130:8081" # Should success (Internal traffic allowed)
      test-webapp "http://#{ip_prefix}.130:9090" # Should succeed (Internal traffic allowed)
      test-webapp "http://#{ip_prefix}.130:9091" # Should success (Internal traffic allowed)

      test-webapp ! "http://localhost:8080" # Service ports not accessible via localhost
      test-webapp ! "http://localhost:8081" # Service ports not accessible via localhost
      test-webapp ! "http://localhost:9090" # Service ports not accessible via localhost
      test-webapp ! "http://localhost:9091" # Service ports not accessible via localhost

      # Internal Communication Tests
      # Get Container ID for test_service_a
      service_a_container=$(docker ps --filter "name=test_service_a" -q | head -n 1)
      
      if [ -n "$service_a_container" ]; then
         # Service A -> Service B (Port 80) - Should succeed
         test-webapp --container "$service_a_container" "test_service_b" 80
         # Service A -> Service B (Port 8080) - Should succeed (Internal traffic allowed)
         test-webapp --container "$service_a_container" "test_service_b" 8080
      else
         echo "WARNING: Could not find running container for test_service_a on master node. Skipping internal tests."
      fi

      #{TEST_WEBAPP_RESULT}
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
        #{TEST_WEBAPP_SCRIPT}

        function run_tests() {
          local server="$1"
          test-webapp "$server:18080"
          test-webapp ! "$server:8000"

          test-webapp "$server:17070" # multiple networks app
          test-webapp ! "$server:7000" # internal multiple networks app

          # UDP Test
          local host="${server#*://}"
          test-udp "$host" 30000
          test-udp ! "$host" 30001

          # Delete Rule Test
          test-webapp ! "$server:18081"

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

          # Delete Rule Test (IPv6)
          test-webapp ! "$server:18081"
        }

        run_tests "http://#{ip_prefix}.130"
        run_tests_ipv4 "http://#{ip_prefix}.130"

        if #{env_true_str?('ENABLE_DOCKER_IPV6')}; then
          run_tests "http://[#{ip6_prefix}:0:cafe::130]"
          run_tests_ipv6 "http://[#{ip6_prefix}:0:cafe::130]"
        fi

        #{TEST_WEBAPP_RESULT}
    SHELL
  end
end
