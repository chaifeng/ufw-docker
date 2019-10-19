#!/usr/bin/env bash
set -euo pipefail

working_dir="$(cd "$(dirname "$BASH_SOURCE")"; pwd -P)"
source "$working_dir"/bach/bach.sh

@setup {
    set -euo pipefail
}

@setup-test {
    @mocktrue ufw status
    @mocktrue grep -Fq "Status: active"

    @ignore remove_blank_lines
    @ignore echo
    @ignore err
    @ignore die

    DEFAULT_PROTO=tcp
    GREP_REGEXP_INSTANCE_NAME="[-_.[:alnum:]]\\+"
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
