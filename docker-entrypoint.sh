#!/bin/bash

[[ 0 -eq "$#" ]] && set -- start

ufw_docker_agent_image=192.168.56.120:5000/ufw-docker-agent

case "$1" in
    start)
        docker service inspect "$ufw_docker_agent" \
               --format '{{range $k,$v:=.Spec.Labels}}{{$k}} {{$v}}{{"\n"}}{{end}}' |
            while read label port; do
                [[ -z "$label" ]] && continue
                name="${label#ufw.public.}"
                echo "${name}=$port"
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
