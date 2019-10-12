#!/usr/bin/env bash
set -euo pipefail

working_dir="$(cd "$(dirname "$BASH_SOURCE")"; pwd -P)"
source "$working_dir"/bach/bach.sh

@setup-test {
    @mocktrue ufw status
    @mocktrue grep -Fq "Status: active"
}

function ufw-docker() {
    @source <(@sed -n '/^# __main__$/,$p' "$working_dir/../ufw-docker") "$@"
}

test-ufw-docker-help() {
    ufw-docker help
}
test-ufw-docker-help-assert() {
    ufw-docker--help
}


test-ufw-docker-without-parameters() {
    ufw-docker
}
test-ufw-docker-without-parameters-assert() {
    test-ufw-docker-help-assert
}


test-ufw-is-disabled() {
    @mockfalse grep -Fq "Status: active"

    ufw-docker
}
test-ufw-is-disabled-assert() {
    die "UFW is disabled or you are not root user."
    ufw-docker--help
}


test-ufw-docker-status() {
    ufw-docker status
}
test-ufw-docker-status-assert() {
    ufw-docker--status
}


test-ufw-docker-install() {
    ufw-docker install
}
test-ufw-docker-install-assert() {
    ufw-docker--install
}


test-ufw-docker-check() {
    ufw-docker check
}
test-ufw-docker-check-assert() {
    ufw-docker--check
}


test-ufw-docker-service() {
    ufw-docker service allow httpd
}
test-ufw-docker-service-assert() {
    ufw-docker--service allow httpd
}


test-ufw-docker-raw-command() {
    ufw-docker raw-command status
}
test-ufw-docker-raw-command-assert() {
    ufw-docker--raw-command status
}


test-ufw-docker-add-service-rule() {
    ufw-docker add-service-rule httpd 80/tcp
}
test-ufw-docker-add-service-rule-assert() {
    ufw-docker--add-service-rule httpd 80/tcp
}


test-ASSERT-FAIL-ufw-docker-delete-must-have-parameters() {
    ufw-docker delete
}


test-ASSERT-FAIL-ufw-docker-list-must-have-parameters() {
    ufw-docker list
}


test-ASSERT-FAIL-ufw-docker-allow-must-have-parameters() {
    ufw-docker allow
}


test-ASSERT-FAIL-ufw-docker-delete-httpd-but-it-doesnt-exist() {
    @mockfalse ufw-docker--instance-name httpd
    ufw-docker delete httpd
}


test-ASSERT-FAIL-ufw-docker-list-httpd-but-it-doesnt-exist() {
    @mockfalse ufw-docker--instance-name httpd
    ufw-docker list httpd
}


test-ASSERT-FAIL-ufw-docker-allow-httpd-but-it-doesnt-exist() {
    @mockfalse ufw-docker--instance-name httpd
    ufw-docker allow httpd
}


test-ufw-docker-list-httpd() {
    @mock ufw-docker--instance-name httpd === @stdout httpd-container-name
    ufw-docker list httpd
}
test-ufw-docker-list-httpd-assert() {
    ufw-docker--list httpd-container-name "" ""
}


test-ufw-docker-allow-httpd() {
    @mock ufw-docker--instance-name httpd === @stdout httpd-container-name
    ufw-docker allow httpd
}
test-ufw-docker-allow-httpd-assert() {
    ufw-docker--allow httpd-container-name "" ""
}


test-ufw-docker-allow-httpd-80() {
    @mock ufw-docker--instance-name httpd === @stdout httpd-container-name
    ufw-docker allow httpd 80
}
test-ufw-docker-allow-httpd-80-assert() {
    ufw-docker--allow httpd-container-name 80 ""
}


test-ufw-docker-allow-httpd-80tcp() {
    @mock ufw-docker--instance-name httpd === @stdout httpd-container-name
    ufw-docker allow httpd 80/tcp
}
test-ufw-docker-allow-httpd-80tcp-assert() {
    ufw-docker--allow httpd-container-name 80 ""
}


test-ufw-docker-allow-httpd-80udp() {
    @mock ufw-docker--instance-name httpd === @stdout httpd-container-name
    ufw-docker allow httpd 80/udp
}
test-ufw-docker-allow-httpd-80udp-assert() {
    ufw-docker--allow httpd-container-name 80 udp
}


test-ASSERT-FAIL-ufw-docker-allow-httpd-INVALID-port() {
    @mock ufw-docker--instance-name httpd === @stdout httpd-container-name
    @mock die 'invalid port syntax: "invalid".' === exit 1

    ufw-docker allow httpd invalid
}


test-ufw-docker-list-httpd() {
    @mock ufw-docker--instance-name httpd === @stdout httpd-container-name
    ufw-docker list httpd
}
test-ufw-docker-list-httpd-assert() {
    ufw-docker--list httpd-container-name "" ""
}


test-ufw-docker-delete-allow-httpd() {
    @mock ufw-docker--instance-name httpd === @stdout httpd-container-name
    ufw-docker delete allow httpd
}
test-ufw-docker-delete-allow-httpd-assert() {
    ufw-docker--delete httpd-container-name "" ""
}


test-ASSERT-FAIL-ufw-docker-delete-only-supports-allowed-rules() {
    @mock ufw-docker--instance-name httpd === @stdout httpd-container-name
    ufw-docker delete non-allow
}
test-ASSERT-FAIL-ufw-docker-delete-only-supports-allowed-rules-assert() {
    die "\"delete\" command only support removing allowed rules"
}
