# frozen_string_literal: true

# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure('2') do |config|

  config.vm.box = "chaifeng/ubuntu-18.04-docker-18.06"

  config.vm.provider 'virtualbox' do |vb|
    vb.memory = '1024'
  end

  ip_prefix="192.168.56"

  config.vm.provision 'docker', type: 'shell', inline: <<-SHELL
    set -ex
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
    set -ex
    /vagrant/ufw-docker check || {
      ufw allow OpenSSH
      ufw allow from #{ip_prefix}.128/28 to any

      yes | ufw enable
      /vagrant/ufw-docker install

      sed -i -e 's,192\.168\.0\.0/16,#{ip_prefix}.128/28,' /etc/ufw/after.rules

      systemctl restart ufw

      iptables -I DOCKER-USER 4 -p udp -j LOG --log-prefix '[UFW DOCKER] '

      [[ -L /usr/local/bin/ufw-docker ]] || ln -s /vagrant/ufw-docker /usr/local/bin/
    }
  SHELL

  config.vm.define "master" do |master|
    master.vm.hostname = "master"
    master.vm.network "private_network", ip: "#{ip_prefix}.130"

    master.vm.provision "swarm-init", type: 'shell', inline: <<-SHELL
      set -ex
      docker run -d -p 5000:5000 --restart=always --name registry registry:2
      docker swarm init --advertise-addr eth1
      docker swarm join-token worker --quiet > /vagrant/.vagrant/docker-join-token
    SHELL
  end

  1.upto 2 do |ip|
    config.vm.define "node#{ip}" do | node |
      node.vm.hostname = "node#{ip}"
      node.vm.network "private_network", ip: "#{ip_prefix}.#{ 130 + ip }"

      node.vm.provision "swarm-join", type: 'shell', inline: <<-SHELL
        set -ex
        [[ -f /vagrant/.vagrant/docker-join-token ]] &&
        docker swarm join --token "$(</vagrant/.vagrant/docker-join-token)" #{ip_prefix}.130:2377
      SHELL
    end
  end
end
