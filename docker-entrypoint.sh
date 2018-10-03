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
