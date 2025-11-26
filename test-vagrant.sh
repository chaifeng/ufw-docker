#!/usr/bin/env bash
set -euo pipefail

for ENABLE_DOCKER_IPV6 in false true; do
  for USE_IPTABLES_LEGACY in false true; do
    declare -a env_list=(
      ENABLE_DOCKER_IPV6="${ENABLE_DOCKER_IPV6}"
      USE_IPTABLES_LEGACY="${USE_IPTABLES_LEGACY}"
      DOCKER_REGISTRY_MIRROR="${DOCKER_REGISTRY_MIRROR:-}"
      DISABLE_UNIT_TESTING="${DISABLE_UNIT_TESTING:-}"
    )
    if ! (vagrant destroy --force && env "${env_list[@]}" vagrant up); then
      echo "Failed to run vagrant up with env: ${env_list[*]}"
      echo ""
      echo "env ${env_list[*]} vagrant provision"
      exit 1
    fi >&2
  done
done
