#!/usr/bin/env bash
set -euo pipefail

working_dir="$(cd "$(dirname "$BASH_SOURCE")"; pwd -P)"
source "$working_dir"/bach/bach.sh

@setup {
    set -euo pipefail

    ufw_docker_agent=ufw-docker-agent
    ufw_docker_agent_image=chaifeng/ufw-docker-agent:181005
}

@setup-test {
    @mocktrue ufw status
    @mocktrue grep -Fq "Status: active"

    @ignore remove_blank_lines
    @ignore echo
    @ignore err

    DEFAULT_PROTO=tcp
    GREP_REGEXP_INSTANCE_NAME="[-_.[:alnum:]]\\+"
    DEBUG=false
}

function die() {
    return 1
}

function load-ufw-docker-function() {
    set -euo pipefail

    @load_function "$working_dir/../ufw-docker" "$1"
}


test-ufw-docker--service-not-parameters() {
    load-ufw-docker-function ufw-docker--service

    ufw-docker--service
}
test-ufw-docker--service-not-parameters-assert() {
    ufw-docker--help
}


test-ufw-docker--service-allow() {
    load-ufw-docker-function ufw-docker--service

    ufw-docker--service allow
}
test-ufw-docker--service-allow-assert() {
    @do-nothing
    @fail
}


test-ufw-docker--service-allow-webapp() {
    load-ufw-docker-function ufw-docker--service

    ufw-docker--service allow webapp
}
test-ufw-docker--service-allow-webapp-assert() {
    #ufw-docker--service-allow webapp "" ""
    @do-nothing
    @fail
}


test-ufw-docker--service-allow-webapp-80tcp() {
    load-ufw-docker-function ufw-docker--service

    ufw-docker--service allow webapp 80/tcp
}
test-ufw-docker--service-allow-webapp-80tcp-assert() {
    ufw-docker--service-allow webapp 80/tcp
}


test-ufw-docker--service-delete-deny() {
    load-ufw-docker-function ufw-docker--service

    ufw-docker--service delete deny
}
test-ufw-docker--service-delete-deny-assert() {
    @do-nothing
    @fail
}


test-ufw-docker--service-delete-allow-no-service() {
    load-ufw-docker-function ufw-docker--service

    ufw-docker--service delete allow
}
test-ufw-docker--service-delete-allow-no-service-assert() {
    @do-nothing
    @fail
}


test-ufw-docker--service-delete-allow-webapp() {
    load-ufw-docker-function ufw-docker--service

    ufw-docker--service delete allow webapp
}
test-ufw-docker--service-delete-allow-webapp-assert() {
    ufw-docker--service-delete webapp
}


test-ufw-docker--get-service-id() {
    load-ufw-docker-function ufw-docker--get-service-id
    ufw-docker--get-service-id database
}
test-ufw-docker--get-service-id-assert() {
    docker service inspect database --format "{{.ID}}"
}


test-ufw-docker--get-service-name() {
    load-ufw-docker-function ufw-docker--get-service-name
    ufw-docker--get-service-name database
}
test-ufw-docker--get-service-name-assert() {
    docker service inspect database --format "{{.Spec.Name}}"
}


test-ufw-docker--service-allow-invalid-port-syntax() {
    @mockfalse grep -E '^[0-9]+(/(tcp|udp))?$'

    load-ufw-docker-function ufw-docker--service-allow
    ufw-docker--service-allow webapp invalid-port
}
test-ufw-docker--service-allow-invalid-port-syntax-assert() {
    @do-nothing
    @fail
}


test-ufw-docker--service-allow-an-non-existed-service() {
    @mocktrue grep -E '^[0-9]+(/(tcp|udp))?$'
    @mock ufw-docker--get-service-id web404 === @stdout ""

    load-ufw-docker-function ufw-docker--service-allow
    ufw-docker--service-allow web404 80/tcp
}
test-ufw-docker--service-allow-an-non-existed-service-assert() {
    @do-nothing
    @fail
}


test-ufw-docker--service-allow-a-service-without-ports-published() {
    @mocktrue grep -E '^[0-9]+(/(tcp|udp))?$'
    @mock ufw-docker--get-service-id private-web === @stdout abcd1234
    @mock ufw-docker--get-service-name private-web === @stdout private-web
    @mock docker service inspect private-web \
          --format '{{range .Endpoint.Spec.Ports}}{{.PublishedPort}} {{.TargetPort}}/{{.Protocol}}{{"\n"}}{{end}}' === @stdout ""

    load-ufw-docker-function ufw-docker--service-allow
    ufw-docker--service-allow private-web 80/tcp
}
test-ufw-docker--service-allow-a-service-without-ports-published-assert() {
    @do-nothing
    @fail
}


test-ufw-docker--service-allow-a-service-while-agent-not-running() {
    @mocktrue grep -E '^[0-9]+(/(tcp|udp))?$'
    @mock ufw-docker--get-service-id webapp === @stdout abcd1234
    @mock ufw-docker--get-service-name webapp === @stdout webapp
    @mock docker service inspect webapp \
          --format '{{range .Endpoint.Spec.Ports}}{{.PublishedPort}} {{.TargetPort}}/{{.Protocol}}{{"\n"}}{{end}}' \
          === @stdout "53 53/udp" "80 80/tcp" "8080 8080/tcp"
    @mockfalse docker service inspect ufw-docker-agent

    load-ufw-docker-function ufw-docker--service-allow
    ufw-docker--service-allow webapp 80/tcp
}
test-ufw-docker--service-allow-a-service-while-agent-not-running-assert() {
    docker service create --name ufw-docker-agent --mode global \
           --mount type=bind,source=/var/run/docker.sock,target=/var/run/docker.sock \
           --mount type=bind,source=/etc/ufw,target=/etc/ufw,readonly=true \
           --env ufw_docker_agent_image="chaifeng/ufw-docker-agent:181005" \
           --env DEBUG="false" \
           --env "ufw_public_abcd1234=webapp/80/tcp" \
           "chaifeng/ufw-docker-agent:181005"
}


test-ufw-docker--service-allow-a-service-add-new-env() {
    @mocktrue grep -E '^[0-9]+(/(tcp|udp))?$'
    @mock ufw-docker--get-service-id webapp === @stdout abcd1234
    @mock ufw-docker--get-service-name webapp === @stdout webapp
    @mock docker service inspect webapp \
          --format '{{range .Endpoint.Spec.Ports}}{{.PublishedPort}} {{.TargetPort}}/{{.Protocol}}{{"\n"}}{{end}}' \
          === @stdout "53 53/udp" "80 80/tcp" "8080 8080/tcp"
    @mocktrue docker service inspect ufw-docker-agent
    @mock ufw-docker--get-env-list === @stdout "abcd1234 webapp/80/tcp"

    load-ufw-docker-function ufw-docker--service-allow
    ufw-docker--service-allow webapp 80/tcp
}
test-ufw-docker--service-allow-a-service-add-new-env-assert() {
    docker service update --update-parallelism=0 \
           --env-add ufw_docker_agent_image="chaifeng/ufw-docker-agent:181005" \
           --env-add DEBUG="false" \
           --env-add "ufw_public_abcd1234=webapp/80/tcp" \
           --image "chaifeng/ufw-docker-agent:181005" \
           ufw-docker-agent
}


test-ufw-docker--service-allow-a-service-update-a-env() {
    @mocktrue grep -E '^[0-9]+(/(tcp|udp))?$'
    @mock ufw-docker--get-service-id webapp === @stdout abcd1234
    @mock ufw-docker--get-service-name webapp === @stdout webapp
    @mock docker service inspect webapp \
          --format '{{range .Endpoint.Spec.Ports}}{{.PublishedPort}} {{.TargetPort}}/{{.Protocol}}{{"\n"}}{{end}}' \
          === @stdout "53 53/udp" "80 80/tcp" "8080 8080/tcp"
    @mocktrue docker service inspect ufw-docker-agent
    @mock ufw-docker--get-env-list === @stdout "a_different_id webapp/80/tcp"

    load-ufw-docker-function ufw-docker--service-allow
    ufw-docker--service-allow webapp 80/tcp
}
test-ufw-docker--service-allow-a-service-update-a-env-assert() {
    docker service update --update-parallelism=0 \
           --env-add ufw_docker_agent_image="chaifeng/ufw-docker-agent:181005" \
           --env-add DEBUG="false" \
           --env-add "ufw_public_abcd1234=webapp/80/tcp" \
           --env-rm "ufw_public_a_different_id" \
           --image "chaifeng/ufw-docker-agent:181005" \
           ufw-docker-agent
}


test-ufw-docker--get-env-list() {
    @mock docker service inspect ufw-docker-agent \
          --format '{{range $k,$v := .Spec.TaskTemplate.ContainerSpec.Env}}{{ $v }}{{"\n"}}{{end}}' \
          === @stdout \
              "ufw_docker_agent_image=192.168.56.130:5000/chaifeng/ufw-docker-agent:test" \
              "DEBUG=true" \
              "ufw_public_zv6esvmwnmmgnlauqn7m77jo4=webapp/9090/tcp" \
              "OTHER_ENV=blabla"

    @mock sed -e '/^ufw_public_/!d' \
              -e 's/^ufw_public_//' \
              -e 's/=/ /' === @real sed -e '/^ufw_public_/!d' \
                                        -e 's/^ufw_public_//' \
                                        -e 's/=/ /'

    load-ufw-docker-function ufw-docker--get-env-list
    ufw-docker--get-env-list
}
test-ufw-docker--get-env-list-assert() {
    @stdout "zv6esvmwnmmgnlauqn7m77jo4 webapp/9090/tcp"
}


test-ufw-docker--service-delete-no-matches() {
    @mock ufw-docker--get-env-list === @stdout "ffff111 foo/80/tcp" "eeee2222 bar/53/udp"

    load-ufw-docker-function ufw-docker--service-delete
    ufw-docker--service-delete webapp
}
test-ufw-docker--service-delete-no-matches-assert() {
    @do-nothing
    @fail
}


test-ufw-docker--service-delete-matches() {
    @mock ufw-docker--get-env-list === @stdout "ffff111 foo/80/tcp" "eeee2222 bar/53/udp" "abcd1234 webapp/5000/tcp"

    load-ufw-docker-function ufw-docker--service-delete
    ufw-docker--service-delete webapp
}
test-ufw-docker--service-delete-matches-assert() {
    docker service update --update-parallelism=0 \
           --env-add ufw_docker_agent_image="${ufw_docker_agent_image}" \
           --env-add "ufw_public_abcd1234=webapp/deny" \
           --image "${ufw_docker_agent_image}" \
           "${ufw_docker_agent}"
}
