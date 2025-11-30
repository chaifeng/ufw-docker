#!/usr/bin/env bash
set -euo pipefail

reload_tested=false
for ENABLE_DOCKER_IPV6 in true false; do
  for USE_IPTABLES_LEGACY in false true; do
    declare -a env_list=(
      ENABLE_DOCKER_IPV6="${ENABLE_DOCKER_IPV6}"
      USE_IPTABLES_LEGACY="${USE_IPTABLES_LEGACY}"
      DOCKER_REGISTRY_MIRROR="${DOCKER_REGISTRY_MIRROR:-}"
      DISABLE_UNIT_TESTING="${DISABLE_UNIT_TESTING:-}"
      SERVICE_REPLICAS="${SERVICE_REPLICAS:-1}"
      WORKER_COUNT="${WORKER_COUNT:-2}"
    )
    echo "vagrant destroy --force && env ${env_list[*]} vagrant up" >&2
    if ! (vagrant destroy --force && env "${env_list[@]}" vagrant up); then
      echo "Failed to run vagrant up with env: ${env_list[*]}"
      echo ""
      echo "env ${env_list[*]} vagrant provision"
      exit 1
    fi >&2
    if ! "$reload_tested"; then
      echo "Testing ufw-docker reload ..." >&2
      vagrant ssh master -c 'sudo systemctl restart docker'
      vagrant provision external || true
      vagrant ssh master -c 'sudo /vagrant/ufw-docker reload'
      sleep 10
      vagrant provision external
      reload_tested=true
      exit
    fi
  done
done
