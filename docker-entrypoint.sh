#!/bin/bash
set -euo pipefail

[[ 0 -eq "$#" ]] && set -- start

ufw_docker_agent=ufw-docker-agent
ufw_docker_agent_image="${ufw_docker_agent_image:-chaifeng/${ufw_docker_agent}:181003}"

function ufw-update-service-instances() {
    id="$1"
    port="$2"

    declare -a opts
    [[ "$port" = deny ]] && opts+=(delete)
    opts+=(allow)

    [[ "$port" = @(all|deny) ]] && port=""

    docker ps -qf "label=com.docker.swarm.service.id=${id}" |
        while read name; do
            echo "$id $name $port"
            run-ufw-docker "${opts[@]}" "${name}" "$port"
        done
}

function update-ufw-rules() {
    declare -p | sed -e '/^declare -x ufw_public_/!d' \
                     -e 's/^declare -x ufw_public_//' \
                     -e 's/="/ /' \
                     -e 's/"$//' |
        while read id port; do
            echo "${id}=$port"
            ufw-update-service-instances "${id}" "${port}"
        done
}

function run-ufw-docker() {
    declare -a docker_opts=(run --rm -t --name ufw-docker-agent-"${RANDOM}"-$(date '+%Y%m%d%H%M%S')
         --cap-add NET_ADMIN --network host
         --env UFW_DOCKER_FORCE_ADD=yes
         -v /var/run/docker.sock:/var/run/docker.sock
         -v /etc/ufw:/etc/ufw "${ufw_docker_agent_image}" "$@")
    docker "${docker_opts[@]}"
}

function get-service-name-of() {
    docker inspect "$1" --format '{{range $k,$v:=.Config.Labels}}{{ if eq $k "com.docker.swarm.service.name" }}{{$v}}{{end}}{{end}}' | grep -E "^.+\$"
}

function get-service-id-of() {
    docker inspect "$1" --format '{{range $k,$v:=.Config.Labels}}{{ if eq $k "com.docker.swarm.service.id" }}{{$v}}{{end}}{{end}}' | grep -E "^.+\$"
}

case "$1" in
    start)
        update-ufw-rules
        docker events --format '{{.Time}} {{.Status}} {{.Actor.Attributes.name}}' --filter 'scope=local' --filter 'type=container' |
            while read time status name; do
                echo "$time $status $name" >&2
                [[ -z "$name" ]] && continue

                [[ "$status" = @(kill|start) ]] || continue

                declare -n env_name="ufw_public_$(get-service-id-of "$name")"
                [[ -z "${env_name:-}" ]] && continue

                declare -a agent_opts=()
                if [[ "$status" = kill ]]; then
                    agent_opts+=(delete allow "$name")
                fi

                run-ufw-docker "${agent_opts[@]}" >&2
            done
        sleep 60; exit 1
        ;;
    delete|allow)
        ufw-docker "$@"
        ;;
    update-ufw-rules)
        update-ufw-rules
        ;;
    *)
        if [[ -f "$1" ]]; then
            exec "$@"
        else
            echo "Unknown parameters: $@" >&2
            exit 1
        fi
esac
