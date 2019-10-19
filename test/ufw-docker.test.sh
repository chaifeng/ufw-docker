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

    DEFAULT_PROTO=tcp
    GREP_REGEXP_INSTANCE_NAME="[-_.[:alnum:]]\\+"
}

function ufw-docker() {
    @source <(@sed -n '/^# __main__$/,$p' "$working_dir/../ufw-docker") "$@"
}

function load-ufw-docker-function() {
    set -euo pipefail

    @load_function "$working_dir/../ufw-docker" "$1"
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
    ufw-docker--list httpd-container-name "" tcp
}


test-ufw-docker-allow-httpd() {
    @mock ufw-docker--instance-name httpd === @stdout httpd-container-name
    ufw-docker allow httpd
}
test-ufw-docker-allow-httpd-assert() {
    ufw-docker--allow httpd-container-name "" tcp
}


test-ufw-docker-allow-httpd-80() {
    @mock ufw-docker--instance-name httpd === @stdout httpd-container-name
    ufw-docker allow httpd 80
}
test-ufw-docker-allow-httpd-80-assert() {
    ufw-docker--allow httpd-container-name 80 tcp
}


test-ufw-docker-allow-httpd-80tcp() {
    @mock ufw-docker--instance-name httpd === @stdout httpd-container-name
    ufw-docker allow httpd 80/tcp
}
test-ufw-docker-allow-httpd-80tcp-assert() {
    ufw-docker--allow httpd-container-name 80 tcp
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
    ufw-docker--list httpd-container-name "" tcp
}


test-ufw-docker-delete-allow-httpd() {
    @mock ufw-docker--instance-name httpd === @stdout httpd-container-name
    ufw-docker delete allow httpd
}
test-ufw-docker-delete-allow-httpd-assert() {
    ufw-docker--delete httpd-container-name "" tcp
}


test-ASSERT-FAIL-ufw-docker-delete-only-supports-allowed-rules() {
    @mock ufw-docker--instance-name httpd === @stdout httpd-container-name
    ufw-docker delete non-allow
}
test-ASSERT-FAIL-ufw-docker-delete-only-supports-allowed-rules-assert() {
    die "\"delete\" command only support removing allowed rules"
}


function setup-ufw-docker--allow() {
    load-ufw-docker-function ufw-docker--allow

    @mocktrue docker inspect instance-name
    @mock docker inspect --format='{{range .NetworkSettings.Networks}}{{.IPAddress}}{{"\n"}}{{end}}' instance-name === @stdout 172.18.0.3
    @mock docker inspect --format='{{range $p, $conf := .NetworkSettings.Ports}}{{with $conf}}{{$p}}{{"\n"}}{{end}}{{end}}' instance-name === @stdout 5000/tcp 8080/tcp 5353/udp
}


test-ufw-docker--allow-instance-not-found() {
    setup-ufw-docker--allow

    @mockfalse docker inspect invalid-instance
    @mockfalse die "Docker instance \"invalid-instance\" doesn't exist."

    ufw-docker--allow invalid-instance 80 tcp
}
test-ufw-docker--allow-instance-not-found-assert() {
    @do-nothing
    @fail
}


test-ufw-docker--allow-instance-but-the-port-not-match() {
    setup-ufw-docker--allow

    ufw-docker--allow instance-name 80 tcp
}
test-ufw-docker--allow-instance-but-the-port-not-match-assert() {
    @do-nothing
    @fail
}


test-ufw-docker--allow-instance-but-the-proto-not-match() {
    setup-ufw-docker--allow

    ufw-docker--allow instance-name 5353 tcp
}
test-ufw-docker--allow-instance-but-the-proto-not-match-assert() {
    @do-nothing
    @fail
}


test-ufw-docker--allow-instance-and-match-the-port() {
    setup-ufw-docker--allow

    ufw-docker--allow instance-name 5000 tcp
}
test-ufw-docker--allow-instance-and-match-the-port-assert() {
    ufw-docker--add-rule instance-name 172.18.0.3 5000 tcp
}


test-ufw-docker--allow-instance-all-published-port() {
    setup-ufw-docker--allow

    ufw-docker--allow instance-name "" ""
}
test-ufw-docker--allow-instance-all-published-port-assert() {
    ufw-docker--add-rule instance-name 172.18.0.3 5000 tcp
    ufw-docker--add-rule instance-name 172.18.0.3 8080 tcp
    ufw-docker--add-rule instance-name 172.18.0.3 5353 udp
}


test-ufw-docker--allow-instance-all-published-tcp-port() {
    setup-ufw-docker--allow

    ufw-docker--allow instance-name "" tcp
}
test-ufw-docker--allow-instance-all-published-tcp-port-assert() {
    ufw-docker--add-rule instance-name 172.18.0.3 5000 tcp
    ufw-docker--add-rule instance-name 172.18.0.3 8080 tcp
    ufw-docker--add-rule instance-name 172.18.0.3 5353 udp # FIXME
}


test-ufw-docker--add-rule-a-non-existing-rule() {
    @mockfalse ufw-docker--list webapp 5000 tcp

    load-ufw-docker-function ufw-docker--add-rule
    ufw-docker--add-rule webapp 172.18.0.4 5000 tcp
}
test-ufw-docker--add-rule-a-non-existing-rule-assert() {
    ufw route allow proto tcp from any to 172.18.0.4 port 5000 comment "allow webapp 5000/tcp"
}


test-ufw-docker--add-rule-modify-an-existing-rule() {
    @mocktrue ufw-docker--list webapp 5000 tcp
    @mocktrue ufw --dry-run route allow proto tcp from any to 172.18.0.4 port 5000 comment "allow webapp 5000/tcp"
    @mockfalse grep "^Skipping"

    load-ufw-docker-function ufw-docker--add-rule
    ufw-docker--add-rule webapp 172.18.0.4 5000 tcp
}
test-ufw-docker--add-rule-modify-an-existing-rule-assert() {
    ufw-docker--delete webapp 5000 tcp

    ufw route allow proto tcp from any to 172.18.0.4 port 5000 comment "allow webapp 5000/tcp"
}


test-ufw-docker--add-rule-skip-an-existing-rule() {
    @mocktrue ufw-docker--list webapp 5000 tcp
    @mocktrue ufw --dry-run route allow proto tcp from any to 172.18.0.4 port 5000 comment "allow webapp 5000/tcp"
    @mocktrue grep "^Skipping"

    load-ufw-docker-function ufw-docker--add-rule
    ufw-docker--add-rule webapp 172.18.0.4 5000 tcp
}
test-ufw-docker--add-rule-skip-an-existing-rule-assert() {
    @do-nothing
}


test-ufw-docker--add-rule-modify-an-existing-rule-without-port() {
    @mocktrue ufw-docker--list webapp "" tcp

    @mocktrue ufw --dry-run route allow proto tcp from any to 172.18.0.4 comment "allow webapp"
    @mockfalse grep "^Skipping"

    load-ufw-docker-function ufw-docker--add-rule

    ufw-docker--add-rule webapp 172.18.0.4 "" tcp
}
test-ufw-docker--add-rule-modify-an-existing-rule-without-port-assert() {
    ufw-docker--delete webapp "" tcp

    ufw route allow proto tcp from any to 172.18.0.4 comment "allow webapp"
}


test-ufw-docker--instance-name-found-a-name() {
    @mock docker inspect --format="{{.Name}}" foo
    @mock sed -e 's,^/,,'
    @mockfalse grep "^$GREP_REGEXP_INSTANCE_NAME\$"

    @mock echo -n foo

    load-ufw-docker-function ufw-docker--instance-name
    ufw-docker--instance-name foo
}
test-ufw-docker--instance-name-found-a-name-assert() {
    docker inspect --format="{{.Name}}" foo
    echo -n foo
}


test-ufw-docker--instance-name-found-an-id() {
    @mock docker inspect --format="{{.Name}}" fooid
    @mock sed -e 's,^/,,'
    @mockfalse grep "^$GREP_REGEXP_INSTANCE_NAME\$"

    load-ufw-docker-function ufw-docker--instance-name
    ufw-docker--instance-name fooid
}
test-ufw-docker--instance-name-found-an-id-assert() {
    docker inspect --format="{{.Name}}" fooid
}
