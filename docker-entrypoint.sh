#!/bin/bash

[[ 0 -eq "$#" ]] && set -- start

ufw_docker_agent=ufw-docker-agent

function ufw_update_service_instances() {
    name="$1"
    port="$2"

    declare -a opts=("$name")
    [[ "$port" = all ]] || opts+=("$port")

    docker ps -qf "label=com.docker.swarm.service.name=${name}" |
        while read name; do
            echo ufw-docker allow "${opts[@]}"
        done
}

case "$1" in
    start)
        declare -p | sed -e '/^declare -x ufw_public_/!d' \
                         -e 's/^declare -x ufw_public_//' \
                         -e 's/="/ /' \
                         -e 's/"$//' |
            while read name port; do
                echo "${name}=$port"
                ufw_update_service_instances "${name}" "${port}"
            done
        docker events --format '{{.Time}} {{.Status}} {{.Actor.Attributes.name}}' --filter 'scope=local' --filter 'type=container' |
            while read time status name; do
                echo "$time $status $name" >&2

                declare -a agent_opts=(run --rm --cap-add NET_ADMIN --network host -v /etc/ufw:/etc/ufw "${ufw_docker_agent_image}")
                [[ "status" = start ]] && agent_opts+=(allow "$name")
                [[ "status" = stop ]] && agent_opts+=(delete allow "$name")

                echo docker "${agent_opts[@]}"
            done
        sleep 60; exit 1
        ;;
    delete|allow)
        ufw-docker "$@"
        ;;
    *)
        if [[ -f "$1" ]]; then
            exec "$@"
        else
            echo "Unknown parameters: $@" >&2
            exit 1
        fi
esac
