#!/bin/bash

[[ 0 -eq "$#" ]] && set -- start

ufw_docker_agent=ufw-docker-agent
ufw_docker_agent_image="${ufw_docker_agent_image:-chaifeng/${ufw_docker_agent}:181003}"

function ufw-update-service-instances() {
    name="$1"
    port="$2"

    declare -a opts=("$name")
    [[ "$port" = all ]] || opts+=("$port")

    docker ps -qf "label=com.docker.swarm.service.name=${name}" |
        while read name; do
            ufw-docker allow "${opts[@]}"
        done
}

function update-ufw-rules() {
    declare -p | sed -e '/^declare -x ufw_public_/!d' \
                     -e 's/^declare -x ufw_public_//' \
                     -e 's/="/ /' \
                     -e 's/"$//' |
        while read name port; do
            echo "${name}=$port"
            ufw-update-service-instances "${name}" "${port}"
        done
}

function run-ufw-docker() {
    echo docker run --rm --cap-add NET_ADMIN --network host -v /etc/ufw:/etc/ufw "${ufw_docker_agent}" "$@"
}

function get-service-name-of() {
    docker inspect "$1" --format '{{range $k,$v:=.Config.Labels}}{{ if eq $k "com.docker.swarm.service.name" }}{{$v}}{{end}}{{end}}' | grep -E "^.+\$"
}

function get-service-id-of() {
    docker inspect "$1" --format '{{range $k,$v:=.Config.Labels}}{{ if eq $k "com.docker.swarm.service.id" }}{{$v}}{{end}}{{end}}' | grep -E "^.+\$"
}

case "$1" in
    start)
        run-ufw-docker update-ufw-rules
        docker events --format '{{.Time}} {{.Status}} {{.Actor.Attributes.name}}' --filter 'scope=local' --filter 'type=container' |
            while read time status name; do
                echo "$time $status $name" >&2

                [[ "$status" = @(kill|start) ]] || continue

                declare -n env_name="ufw_public_$(get-service-id-of "$name")"
                [[ -z "$env_name" ]] && continue

                declare -a agent_opts=()
                [[ "$status" = start ]] && agent_opts+=(allow "$name")
                [[ "$status" = kill ]] && agent_opts+=(delete allow "$name")

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
