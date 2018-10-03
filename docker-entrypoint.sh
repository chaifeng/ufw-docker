#!/bin/bash

[[ 0 -eq "$#" ]] && set -- start

ufw_docker_agent_image=192.168.56.120:5000/ufw-docker-agent

case "$1" in
    start)
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
