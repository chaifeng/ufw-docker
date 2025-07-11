#!/usr/bin/env bash
set -euo pipefail

working_dir="$(cd "$(dirname "$BASH_SOURCE")"; pwd -P)"
source "$working_dir"/bach/bach.sh

@setup {
    set -euo pipefail
    ufw_docker_agent=ufw-docker-agent
    ufw_docker_agent_image=chaifeng/ufw-docker-agent:090502
}

@setup-test {
    @mocktrue ufw status
    @mocktrue grep -Fq "Status: active"

    @ignore remove_blank_lines
    @ignore echo
    @ignore err

    UFW_DOCKER_AGENT_IMAGE=chaifeng/ufw-docker-agent:090502
    builtin source <(@sed -n -e '/^# UFW-DOCKER GLOBAL VARIABLES START #$/,/^# UFW-DOCKER GLOBAL VARIABLES END #$/{' -e '/^PATH=/d' -e 'p' -e '}' "$working_dir/../ufw-docker")

    DEBUG=false

    unset RANDOM
    RANDOM=42

    @allow-real sed -e '/^ufw_public_/!d' -e 's/^ufw_public_//' -e 's/=/ /'
    @allow-real tr ',' '\n'
    @allow-real grep -E '^[0-9]+(/(tcp|udp))?$'
}

function die() {
    return 1
}

function load-ufw-docker-function() {
    set -euo pipefail

    @load_function "$working_dir/../ufw-docker" "$1"
}


test-service-called-without-parameters() {
    load-ufw-docker-function ufw-docker--service

    ufw-docker--service
}
test-service-called-without-parameters-assert() {
    ufw-docker--help
}


test-service-allow-requires-service-name() {
    load-ufw-docker-function ufw-docker--service

    ufw-docker--service allow
}
test-service-allow-requires-service-name-assert() {
    @do-nothing
    @fail
}


test-service-allow-requires-port() {
    load-ufw-docker-function ufw-docker--service

    ufw-docker--service allow webapp
}
test-service-allow-requires-port-assert() {
    #ufw-docker--service-allow webapp "" ""
    @do-nothing
    @fail
}


test-service-allow-succeeds-with-service-and-port() {
    load-ufw-docker-function ufw-docker--service

    ufw-docker--service allow webapp 80/tcp
}
test-service-allow-succeeds-with-service-and-port-assert() {
    ufw-docker--service-allow webapp 80/tcp
}


test-service-delete-deny-is-not-supported() {
    load-ufw-docker-function ufw-docker--service

    ufw-docker--service delete deny
}
test-service-delete-deny-is-not-supported-assert() {
    @do-nothing
    @fail
}


test-service-delete-allow-requires-service-name() {
    load-ufw-docker-function ufw-docker--service

    ufw-docker--service delete allow
}
test-service-delete-allow-requires-service-name-assert() {
    @do-nothing
    @fail
}


test-service-delete-allow-succeeds-with-service-name() {
    load-ufw-docker-function ufw-docker--service

    ufw-docker--service delete allow webapp
}
test-service-delete-allow-succeeds-with-service-name-assert() {
    ufw-docker--service-delete webapp
}


test-service-delete-allow-succeeds-with-service-name-and-port-protocol() {
    load-ufw-docker-function ufw-docker--service

    ufw-docker--service delete allow webapp 8080/tcp
}
test-service-delete-allow-succeeds-with-service-name-and-port-protocol-assert() {
    ufw-docker--service-delete webapp 8080/tcp
}


test-service-delete-allow-succeeds-with-service-name-and-port() {
    load-ufw-docker-function ufw-docker--service

    ufw-docker--service delete allow webapp 8080
}
test-service-delete-allow-succeeds-with-service-name-and-port-assert() {
    ufw-docker--service-delete webapp 8080
}


test-get-service-id() {
    load-ufw-docker-function ufw-docker--get-service-id
    ufw-docker--get-service-id database
}
test-get-service-id-assert() {
    docker service inspect database --format "{{.ID}}"
}


test-get-service-name() {
    load-ufw-docker-function ufw-docker--get-service-name
    ufw-docker--get-service-name database
}
test-get-service-name-assert() {
    docker service inspect database --format "{{.Spec.Name}}"
}


test-service-allow-requires-service-name-invalid-port-syntax() {
    load-ufw-docker-function ufw-docker--service-allow
    ufw-docker--service-allow webapp invalid-port
}
test-service-allow-requires-service-name-invalid-port-syntax-assert() {
    @do-nothing
    @fail
}


test-service-allow-requires-service-name-an-non-existed-service() {
    @mock ufw-docker--get-service-id web404 === @stdout ""

    load-ufw-docker-function ufw-docker--service-allow
    ufw-docker--service-allow web404 80/tcp
}
test-service-allow-requires-service-name-an-non-existed-service-assert() {
    @do-nothing
    @fail
}


test-service-allow-requires-service-name-a-service-without-ports-published() {
    @mock ufw-docker--get-service-id private-web === @stdout abcd1234
    @mock ufw-docker--get-service-name private-web === @stdout private-web
    @mock ufw-docker--list-service-ports private-web === @stdout ""

    load-ufw-docker-function ufw-docker--service-allow
    ufw-docker--service-allow private-web 80/tcp
}
test-service-allow-requires-service-name-a-service-without-ports-published-assert() {
    @do-nothing
    @fail
}


test-service-allow-requires-service-name-a-service-while-agent-not-running() {
    @mock ufw-docker--get-service-id webapp === @stdout abcd1234
    @mock ufw-docker--get-service-name webapp === @stdout webapp
    @mock ufw-docker--list-service-ports webapp === @stdout "53 53/udp" "80 80/tcp" "8080 8080/tcp"
    @mockfalse docker service inspect ufw-docker-agent

    load-ufw-docker-function ufw-docker--service-allow
    ufw-docker--service-allow webapp 80/tcp
}
test-service-allow-requires-service-name-a-service-while-agent-not-running-assert() {
    docker service create --name ufw-docker-agent --mode global \
           --mount type=bind,source=/var/run/docker.sock,target=/var/run/docker.sock \
           --mount type=bind,source=/etc/ufw,target=/etc/ufw,readonly=true \
           --env ufw_docker_agent_image="chaifeng/ufw-docker-agent:090502" \
           --env DEBUG="false" \
           --env "ufw_public_abcd1234=webapp/80/tcp" \
           "chaifeng/ufw-docker-agent:090502"
}


test-service-allow-requires-service-name-a-service-add-new-env() {
    @mock ufw-docker--get-service-id webapp === @stdout abcd1234
    @mock ufw-docker--get-service-name webapp === @stdout webapp
    @mock ufw-docker--list-service-ports webapp === @stdout "53 53/udp" "80 80/tcp" "8080 8080/tcp"
    @mocktrue docker service inspect ufw-docker-agent
    @mock ufw-docker--get-env-list === @stdout "abcd1234 webapp/80/tcp"

    load-ufw-docker-function ufw-docker--service-allow
    ufw-docker--service-allow webapp 80/tcp
}
test-service-allow-requires-service-name-a-service-add-new-env-assert() {
    docker service update --update-parallelism=0 \
           --env-add ufw_docker_agent_image="chaifeng/ufw-docker-agent:090502" \
           --env-add DEBUG="false" \
           --env-add "ufw_public_abcd1234=webapp/80/tcp" \
           --image "chaifeng/ufw-docker-agent:090502" \
           ufw-docker-agent
}


test-service-allow-requires-service-name-a-service-update-a-env() {
    @mock ufw-docker--get-service-id webapp === @stdout abcd1234
    @mock ufw-docker--get-service-name webapp === @stdout webapp
    @mock ufw-docker--list-service-ports webapp === @stdout "53 53/udp" "80 80/tcp" "8080 8080/tcp"
    @mocktrue docker service inspect ufw-docker-agent
    @mock ufw-docker--get-env-list === @stdout "a_different_id webapp/80/tcp"

    load-ufw-docker-function ufw-docker--service-allow
    ufw-docker--service-allow webapp 80/tcp
}
test-service-allow-requires-service-name-a-service-update-a-env-assert() {
    docker service update --update-parallelism=0 \
           --env-add ufw_docker_agent_image="chaifeng/ufw-docker-agent:090502" \
           --env-add DEBUG="false" \
           --env-rm "ufw_public_a_different_id" \
           --env-add "ufw_public_abcd1234=webapp/80/tcp" \
           --image "chaifeng/ufw-docker-agent:090502" \
           ufw-docker-agent
}


test-service-allow-requires-service-name-a-service-add-value-to-an-env() {
    @mock ufw-docker--get-service-id webapp === @stdout abcd1234
    @mock ufw-docker--get-service-name webapp === @stdout webapp
    @mock ufw-docker--list-service-ports webapp === @stdout "5353 53/udp" "8080 80/tcp" "18080 8080/tcp"
    @mocktrue docker service inspect ufw-docker-agent
    @mock ufw-docker--get-env-list === @stdout "a_different_id webapp/8080/tcp" "abcd1234 webapp/5353/udp"

    load-ufw-docker-function ufw-docker--service-allow
    ufw-docker--service-allow webapp 80/tcp
    ufw-docker--service-allow webapp 8080/tcp
}
test-service-allow-requires-service-name-a-service-add-value-to-an-env-assert() {
    docker service update --update-parallelism=0 \
           --env-add ufw_docker_agent_image="chaifeng/ufw-docker-agent:090502" \
           --env-add DEBUG="false" \
           --env-rm "ufw_public_a_different_id" \
           --env-add "ufw_public_abcd1234=webapp/8080/tcp,webapp/5353/udp" \
           --image "chaifeng/ufw-docker-agent:090502" \
           ufw-docker-agent
    docker service update --update-parallelism=0 \
           --env-add ufw_docker_agent_image="chaifeng/ufw-docker-agent:090502" \
           --env-add DEBUG="false" \
           --env-rm "ufw_public_a_different_id" \
           --env-add "ufw_public_abcd1234=webapp/18080/tcp,webapp/5353/udp" \
           --image "chaifeng/ufw-docker-agent:090502" \
           ufw-docker-agent
}

test-service-allow-requires-service-name-a-service-denied-port() {
    @mock ufw-docker--get-service-id webapp === @stdout abcd1234
    @mock ufw-docker--get-service-name webapp === @stdout webapp
    @mock ufw-docker--list-service-ports webapp === @stdout "5353 53/udp" "8080 80/tcp" "18080 8080/tcp"
    @mocktrue docker service inspect ufw-docker-agent
    @mock ufw-docker--get-env-list === @stdout "a_different_id webapp/8080/tcp" "abcd1234 webapp/8080/tcp/deny" "abcd1234 webapp/5353/udp"

    load-ufw-docker-function ufw-docker--service-allow
    ufw-docker--service-allow webapp 80/tcp
}
test-service-allow-requires-service-name-a-service-denied-port-assert() {
    docker service update --update-parallelism=0 \
           --env-add ufw_docker_agent_image="chaifeng/ufw-docker-agent:090502" \
           --env-add DEBUG="false" \
           --env-rm "ufw_public_a_different_id" \
           --env-add "ufw_public_abcd1234=webapp/8080/tcp,webapp/5353/udp" \
           --image "chaifeng/ufw-docker-agent:090502" \
           ufw-docker-agent
}


test-get-env-list() {
    @mock docker service inspect ufw-docker-agent \
          --format '{{range $k,$v := .Spec.TaskTemplate.ContainerSpec.Env}}{{ $v }}{{"\n"}}{{end}}' \
          === @stdout \
          "ufw_docker_agent_image=192.168.56.130:5000/chaifeng/ufw-docker-agent:test" \
          "DEBUG=true" \
          "ufw_public_id111111=webapp/9090/tcp" \
          "ufw_public_id222222=foo/2222/udp" \
          "OTHER_ENV=blabla"

    @allow-real sed "s/^/id111111 /g"
    @allow-real sed "s/^/id222222 /g"

    load-ufw-docker-function ufw-docker--get-env-list
    ufw-docker--get-env-list
}
test-get-env-list-assert() {
    @stdout "id111111 webapp/9090/tcp"
    @stdout "id222222 foo/2222/udp"
}

test-get-env-list-with-multiple-values() {
    @mock docker service inspect ufw-docker-agent \
          --format '{{range $k,$v := .Spec.TaskTemplate.ContainerSpec.Env}}{{ $v }}{{"\n"}}{{end}}' \
          === @stdout \
          "ufw_docker_agent_image=192.168.56.130:5000/chaifeng/ufw-docker-agent:test" \
          "DEBUG=true" \
          "ufw_public_id111111=webapp/9090/tcp,webapp/8888/tcp,webapp/5555/udp" \
          "ufw_public_id222222=foo/2222/udp,foo/3333/tcp" \
          "OTHER_ENV=blabla"

    @allow-real sed "s/^/id111111 /g"
    @allow-real sed "s/^/id222222 /g"

    load-ufw-docker-function ufw-docker--get-env-list
    ufw-docker--get-env-list
}
test-get-env-list-with-multiple-values-assert() {
    @stdout "id111111 webapp/9090/tcp"
    @stdout "id111111 webapp/8888/tcp"
    @stdout "id111111 webapp/5555/udp"
    @stdout "id222222 foo/2222/udp"
    @stdout "id222222 foo/3333/tcp"
}


test-service-delete-fails-for-non-existent-service() {
    @mockfalse ufw-docker--get-service-id webapp

    load-ufw-docker-function ufw-docker--service-delete
    ufw-docker--service-delete webapp
}
test-service-delete-fails-for-non-existent-service-assert() {
    @do-nothing
    @fail
}

function mock-abcd1234-webapp() {
    @mock ufw-docker--get-service-name webapp === @stdout webapp
    @mock ufw-docker--get-service-id webapp === @stdout "abcd1234"
    @mock ufw-docker--list-service-ports webapp === @stdout "22 2222/tcp" "80 8080/tcp" "53 5353/udp"
}

test-service-delete-all-ports-for-service() {
    mock-abcd1234-webapp
    @mock ufw-docker--get-env-list === @stdout "xxx 888/tcp" "abcd1234 webapp/22/tcp"

    load-ufw-docker-function ufw-docker--service-delete
    ufw-docker--service-delete webapp
}
test-service-delete-all-ports-for-service-assert() {
    docker service update --update-parallelism=0 \
           --env-add ufw_docker_agent_image="${ufw_docker_agent_image}" \
           --env-add "ufw_public_abcd1234=webapp/deny" \
           --env-add "DEBUG=false" \
           --image "${ufw_docker_agent_image}" \
           "${ufw_docker_agent}"
}

test-service-delete-all-ports-for-service-with-multiple-rules() {
    mock-abcd1234-webapp
    @mock ufw-docker--get-env-list === @stdout "xxx 888/tcp" "abcd1234 webapp/22/tcp" "abcd1234 webapp/53/udp" "abcd1234 webapp/80/tcp"

    load-ufw-docker-function ufw-docker--service-delete
    ufw-docker--service-delete webapp
}
test-service-delete-all-ports-for-service-with-multiple-rules-assert() {
    docker service update --update-parallelism=0 \
           --env-add ufw_docker_agent_image="${ufw_docker_agent_image}" \
           --env-add "ufw_public_abcd1234=webapp/deny" \
           --env-add "DEBUG=false" \
           --image "${ufw_docker_agent_image}" \
           "${ufw_docker_agent}"
}


test-service-delete-specific-port-for-service() {
    mock-abcd1234-webapp
    @mock ufw-docker--get-env-list === @stdout "xxx 888/tcp" "abcd1234 webapp/80/tcp"

    load-ufw-docker-function ufw-docker--service-delete
    ufw-docker--service-delete webapp 8080
}
test-service-delete-specific-port-for-service-assert() {
    docker service update --update-parallelism=0 \
           --env-add ufw_docker_agent_image="${ufw_docker_agent_image}" \
           --env-add "ufw_public_abcd1234=webapp/80/tcp/deny" \
           --env-add "DEBUG=false" \
           --image "${ufw_docker_agent_image}" \
           "${ufw_docker_agent}"
}


test-service-delete-specific-port-for-service-from-multiple-rules() {
    mock-abcd1234-webapp
    @mock ufw-docker--get-env-list === @stdout "xxx 888/tcp" "abcd1234 webapp/80/tcp" "abcd1234 webapp/53/udp" "abcd1234 webapp/53/tcp"

    load-ufw-docker-function ufw-docker--service-delete
    ufw-docker--service-delete webapp 8080
}
test-service-delete-specific-port-for-service-from-multiple-rules-assert() {
    docker service update --update-parallelism=0 \
           --env-add ufw_docker_agent_image="${ufw_docker_agent_image}" \
           --env-add "ufw_public_abcd1234=webapp/80/tcp/deny,webapp/53/udp,webapp/53/tcp" \
           --env-add "DEBUG=false" \
           --image "${ufw_docker_agent_image}" \
           "${ufw_docker_agent}"
}


test-service-delete-adds-deny-rule-for-port-without-previous-rule() {
    mock-abcd1234-webapp
    @mock ufw-docker--get-env-list === @stdout "xxx 888/tcp" "abcd1234 webapp/53/tcp"

    load-ufw-docker-function ufw-docker--service-delete
    ufw-docker--service-delete webapp 2222
}
test-service-delete-adds-deny-rule-for-port-without-previous-rule-assert() {
    docker service update --update-parallelism=0 \
           --env-add ufw_docker_agent_image="${ufw_docker_agent_image}" \
           --env-add "ufw_public_abcd1234=webapp/22/tcp/deny,webapp/53/tcp" \
           --env-add "DEBUG=false" \
           --image "${ufw_docker_agent_image}" \
           "${ufw_docker_agent}"
}


test-service-delete-specific-port-protocol-for-service() {
    mock-abcd1234-webapp
    @mock ufw-docker--get-env-list === @stdout "xxx 888/tcp" "abcd1234 webapp/80/tcp"

    load-ufw-docker-function ufw-docker--service-delete
    ufw-docker--service-delete webapp 8080/tcp
}
test-service-delete-specific-port-protocol-for-service-assert() {
    docker service update --update-parallelism=0 \
           --env-add ufw_docker_agent_image="${ufw_docker_agent_image}" \
           --env-add "ufw_public_abcd1234=webapp/80/tcp/deny" \
           --env-add "DEBUG=false" \
           --image "${ufw_docker_agent_image}" \
           "${ufw_docker_agent}"
}

test-service-delete-specific-port-protocol-for-service-from-multiple-rules() {
    mock-abcd1234-webapp
    @mock ufw-docker--get-env-list === @stdout "xxx 888/tcp" "abcd1234 webapp/80/tcp" "abcd1234 webapp/53/udp" "abcd1234 webapp/53/tcp"

    load-ufw-docker-function ufw-docker--service-delete
    ufw-docker--service-delete webapp 5353/udp
}
test-service-delete-specific-port-protocol-for-service-from-multiple-rules-assert() {
    docker service update --update-parallelism=0 \
           --env-add ufw_docker_agent_image="${ufw_docker_agent_image}" \
           --env-add "ufw_public_abcd1234=webapp/53/udp/deny,webapp/80/tcp,webapp/53/tcp" \
           --env-add "DEBUG=false" \
           --image "${ufw_docker_agent_image}" \
           "${ufw_docker_agent}"
}

test-service-delete-fails-for-unmatched-port() {
    mock-abcd1234-webapp

    load-ufw-docker-function ufw-docker--service-delete
    ufw-docker--service-delete webapp 3333
}
test-service-delete-fails-for-unmatched-port-assert() {
    @do-nothing
    @fail
}

test-service-delete-fails-for-unmatched-protocol() {
    @mock ufw-docker--get-service-id webapp === @stdout "abcd1234"
    @mock ufw-docker--get-service-name webapp === @stdout webapp
    @mock ufw-docker--list-service-ports webapp === @stdout "22 2222/tcp" "80 8080/tcp" "53 5353/udp"

    load-ufw-docker-function ufw-docker--service-delete
    ufw-docker--service-delete webapp 8080/udp
}
test-service-delete-fails-for-unmatched-protocol-assert() {
    @do-nothing
    @fail
}

test-list-service-ports() {
    load-ufw-docker-function ufw-docker--list-service-ports
     ufw-docker--list-service-ports foo
}
test-list-service-ports-assert() {
    docker service inspect foo --format '{{range .Endpoint.Spec.Ports}}{{.PublishedPort}} {{.TargetPort}}/{{.Protocol}}{{"\n"}}{{end}}'
}

function setup-mock-for-testing-docker-entrypoint() {
    @mock date '+%Y%m%d%H%M%S' === @stdout 200902140731

    declare -gx ufw_public_id111111=alpha/80/tcp
    declare -gx ufw_public_id222222=beta/deny
    declare -gx ufw_public_id333333=gamma/8080/tcp/deny,gamma/5353/udp

    @allow-real sed -e '/^declare -x ufw_public_/!d' -e 's/^declare -x ufw_public_//' -e 's/="/ /' -e 's/"$//'
    @allow-real tr ',' '\n'
}

test-docker-entrypoint-updates-ufw-rules() {
    setup-mock-for-testing-docker-entrypoint
    declare -x ufw_public_id333333=gamma/8080/tcp/deny,gamma/5353/udp

    @run "$working_dir"/../docker-entrypoint.sh update-ufw-rules
}
test-docker-entrypoint-updates-ufw-rules-assert() {
    declare -a docker_opts=(run --rm -t --name ufw-docker-agent-42-200902140731
                            --cap-add NET_ADMIN --network host --env DEBUG=false
                            -v /var/run/docker.sock:/var/run/docker.sock
                            -v /etc/ufw:/etc/ufw
                            chaifeng/ufw-docker-agent:090502
                           )
    docker "${docker_opts[@]}" add-service-rule id111111 80/tcp
    docker "${docker_opts[@]}" delete allow id222222
    docker "${docker_opts[@]}" delete allow id333333 8080/tcp
    docker "${docker_opts[@]}" add-service-rule id333333 5353/udp
}

test-docker-entrypoint-updates-ufw-rules-with-deny-first() {
    setup-mock-for-testing-docker-entrypoint
    declare -x ufw_public_id333333=gamma/5353/udp,gamma/8080/tcp/deny

    @run "$working_dir"/../docker-entrypoint.sh update-ufw-rules
}
test-docker-entrypoint-updates-ufw-rules-with-deny-first-assert() {
    declare -a docker_opts=(run --rm -t --name ufw-docker-agent-42-200902140731
                            --cap-add NET_ADMIN --network host --env DEBUG=false
                            -v /var/run/docker.sock:/var/run/docker.sock
                            -v /etc/ufw:/etc/ufw
                            chaifeng/ufw-docker-agent:090502
                           )
    docker "${docker_opts[@]}" add-service-rule id111111 80/tcp
    docker "${docker_opts[@]}" delete allow id222222
    docker "${docker_opts[@]}" delete allow id333333 8080/tcp
    docker "${docker_opts[@]}" add-service-rule id333333 5353/udp
}
