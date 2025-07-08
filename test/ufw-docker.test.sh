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

    @mock iptables --version
    @mocktrue grep -F '(legacy)'

    @mocktrue docker -v
    @mock docker -v === @stdout Docker version 0.0.0, build dummy

    @mockpipe remove_blank_lines
    #@ignore echo
    @ignore err

    builtin source <(@sed -n -e '/^# UFW-DOCKER GLOBAL VARIABLES START #$/,/^# UFW-DOCKER GLOBAL VARIABLES END #$/{' -e '/^PATH=/d' -e 'p' -e '}' "$working_dir/../ufw-docker")
    UFW_DOCKER_AGENT_IMAGE=chaifeng/ufw-docker-agent:090502-legacy
}

function ufw-docker() {
    @source <(@sed -n '/^# __main__$/,$p' "$working_dir/../ufw-docker") "$@"
}

function load-ufw-docker-function() {
    set -euo pipefail
    @load_function "$working_dir/../ufw-docker" "$1"
}

test-ufw-docker-init-legacy() {
    @mocktrue grep -F '(legacy)'
    @source <(@sed '/PATH=/d' "$working_dir/../ufw-docker") help
}
test-ufw-docker-init-legacy-assert() {
    iptables --version
    test -n chaifeng/ufw-docker-agent:090502-legacy
    trap on-exit EXIT INT TERM QUIT ABRT ERR
    @dryrun cat
}


test-ufw-docker-init-nf_tables() {
    @mockfalse grep -F '(legacy)'
    @source <(@sed '/PATH=/d' "$working_dir/../ufw-docker") help
}
test-ufw-docker-init-nf_tables-assert() {
    iptables --version
    test -n chaifeng/ufw-docker-agent:090502-nf_tables
    trap on-exit EXIT INT TERM QUIT ABRT ERR
    @dryrun cat
}


test-ufw-docker-init() {
    UFW_DOCKER_AGENT_IMAGE=chaifeng/ufw-docker-agent:100917
    @source <(@sed '/PATH=/d' "$working_dir/../ufw-docker") help
}
test-ufw-docker-init-assert() {
    test -n chaifeng/ufw-docker-agent:100917
    trap on-exit EXIT INT TERM QUIT ABRT ERR
    @dryrun cat
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
    @mock iptables --version === @stdout 'iptables v1.8.4 (legacy)'

    ufw-docker
}
test-ufw-is-disabled-assert() {
    die "UFW is disabled or you are not root user, or mismatched iptables legacy/nf_tables, current iptables v1.8.4 (legacy)"
    ufw-docker--help
}


test-docker-is-installed() {
    @mockfalse docker -v

    ufw-docker
}
test-docker-is-installed-assert() {
    die "Docker executable not found."
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


test-ufw-docker-install--docker-subnets() {
    ufw-docker install --docker-subnets
}
test-ufw-docker-install--docker-subnets-assert() {
    ufw-docker--install --docker-subnets
}


test-ufw-docker-check() {
    ufw-docker check
}
test-ufw-docker-check-assert() {
    ufw-docker--check
}


test-ufw-docker-check--docker-subnets() {
    ufw-docker check --docker-subnets
}
test-ufw-docker-check--docker-subnets-assert() {
    ufw-docker--check --docker-subnets
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
    ufw-docker--list httpd-container-name "" tcp ""
}


test-ufw-docker-allow-httpd() {
    @mock ufw-docker--instance-name httpd === @stdout httpd-container-name
    ufw-docker allow httpd
}
test-ufw-docker-allow-httpd-assert() {
    ufw-docker--allow httpd-container-name "" tcp ""
}


test-ufw-docker-allow-httpd-80() {
    @mock ufw-docker--instance-name httpd === @stdout httpd-container-name
    ufw-docker allow httpd 80
}
test-ufw-docker-allow-httpd-80-assert() {
    ufw-docker--allow httpd-container-name 80 tcp ""
}


test-ufw-docker-allow-httpd-80tcp() {
    @mock ufw-docker--instance-name httpd === @stdout httpd-container-name
    ufw-docker allow httpd 80/tcp
}
test-ufw-docker-allow-httpd-80tcp-assert() {
    ufw-docker--allow httpd-container-name 80 tcp ""
}


test-ufw-docker-allow-httpd-80udp() {
    @mock ufw-docker--instance-name httpd === @stdout httpd-container-name
    ufw-docker allow httpd 80/udp
}
test-ufw-docker-allow-httpd-80udp-assert() {
    ufw-docker--allow httpd-container-name 80 udp ""
}


test-ASSERT-FAIL-ufw-docker-allow-httpd-INVALID-port() {
    @mock ufw-docker--instance-name httpd === @stdout httpd-container-name
    @mock die 'invalid port syntax: "invalid".' === exit 1

    ufw-docker allow httpd invalid
}


test-ufw-docker-delete-allow-httpd() {
    @mock ufw-docker--instance-name httpd === @stdout httpd-container-name
    ufw-docker delete allow httpd
}
test-ufw-docker-delete-allow-httpd-assert() {
    ufw-docker--delete httpd-container-name "" tcp ""
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
    @mock docker inspect --format '{{range $name, $net := .NetworkSettings.Networks}}{{if $net.IPAddress}}{{$name}} {{$net.IPAddress}}{{"\n"}}{{end}}{{if $net.GlobalIPv6Address}}{{$name}} {{$net.GlobalIPv6Address}}{{"\n"}}{{end}}{{end}}' instance-name === @stdout "default 172.18.0.3"
    @mock docker inspect --format='{{range $p, $conf := .NetworkSettings.Ports}}{{with $conf}}{{$p}}{{"\n"}}{{end}}{{end}}' instance-name === @stdout 5000/tcp 8080/tcp 5353/udp
}

function setup-IPv6-ufw-docker--allow() {
    load-ufw-docker-function ufw-docker--allow

    @mocktrue docker inspect instance-name
    @mock docker inspect --format '{{range $name, $net := .NetworkSettings.Networks}}{{if $net.IPAddress}}{{$name}} {{$net.IPAddress}}{{"\n"}}{{end}}{{if $net.GlobalIPv6Address}}{{$name}} {{$net.GlobalIPv6Address}}{{"\n"}}{{end}}{{end}}' instance-name === @stdout "default 172.18.0.3" "default fd00:cf::42"
    @mock docker inspect --format='{{range $p, $conf := .NetworkSettings.Ports}}{{with $conf}}{{$p}}{{"\n"}}{{end}}{{end}}' instance-name === @stdout 5000/tcp 8080/tcp 5353/udp
}

function setup-ufw-docker--allow--multinetwork() {
    load-ufw-docker-function ufw-docker--allow

    @mocktrue docker inspect instance-name
    @mock docker inspect --format '{{range $name, $net := .NetworkSettings.Networks}}{{if $net.IPAddress}}{{$name}} {{$net.IPAddress}}{{"\n"}}{{end}}{{if $net.GlobalIPv6Address}}{{$name}} {{$net.GlobalIPv6Address}}{{"\n"}}{{end}}{{end}}' instance-name === @stdout "default 172.18.0.3" "awesomenet 172.19.0.7"
    @mock docker inspect --format='{{range $p, $conf := .NetworkSettings.Ports}}{{with $conf}}{{$p}}{{"\n"}}{{end}}{{end}}' instance-name === @stdout 5000/tcp 8080/tcp 5353/udp
}

function setup-IPv6-ufw-docker--allow--multinetwork() {
    load-ufw-docker-function ufw-docker--allow

    @mocktrue docker inspect instance-name
    @mock docker inspect --format '{{range $name, $net := .NetworkSettings.Networks}}{{if $net.IPAddress}}{{$name}} {{$net.IPAddress}}{{"\n"}}{{end}}{{if $net.GlobalIPv6Address}}{{$name}} {{$net.GlobalIPv6Address}}{{"\n"}}{{end}}{{end}}' instance-name === @stdout "default 172.18.0.3" "default fd00:cf::42" "awesomenet 172.19.0.7" "awesomenet fd00:cf::207"
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
    ufw-docker--add-rule instance-name 172.18.0.3 5000 tcp default
}


test-ufw-docker--allow-instance-all-published-port() {
    setup-ufw-docker--allow

    ufw-docker--allow instance-name "" ""
}
test-ufw-docker--allow-instance-all-published-port-assert() {
    ufw-docker--add-rule instance-name 172.18.0.3 5000 tcp default
    ufw-docker--add-rule instance-name 172.18.0.3 8080 tcp default
    ufw-docker--add-rule instance-name 172.18.0.3 5353 udp default
}


test-ufw-docker--allow-instance-all-published-tcp-port() {
    setup-ufw-docker--allow

    ufw-docker--allow instance-name "" tcp
}
test-ufw-docker--allow-instance-all-published-tcp-port-assert() {
    ufw-docker--add-rule instance-name 172.18.0.3 5000 tcp default
    ufw-docker--add-rule instance-name 172.18.0.3 8080 tcp default
    ufw-docker--add-rule instance-name 172.18.0.3 5353 udp default # FIXME
}


test-ufw-docker--allow-instance-all-published-port-multinetwork() {
    setup-ufw-docker--allow--multinetwork

    ufw-docker--allow instance-name "" ""
}
test-ufw-docker--allow-instance-all-published-port-multinetwork-assert() {
    ufw-docker--add-rule  instance-name  172.18.0.3  5000  tcp  default
    ufw-docker--add-rule  instance-name  172.19.0.7  5000  tcp  awesomenet
    ufw-docker--add-rule  instance-name  172.18.0.3  8080  tcp  default
    ufw-docker--add-rule  instance-name  172.19.0.7  8080  tcp  awesomenet
    ufw-docker--add-rule  instance-name  172.18.0.3  5353  udp  default
    ufw-docker--add-rule  instance-name  172.19.0.7  5353  udp  awesomenet
}

test-ufw-docker--allow-instance-all-published-port-multinetwork-select-network() {
    setup-ufw-docker--allow--multinetwork

    ufw-docker--allow instance-name "" "" awesomenet
}
test-ufw-docker--allow-instance-all-published-port-multinetwork-select-network-assert() {
    ufw-docker--add-rule  instance-name  172.19.0.7  5000  tcp  awesomenet
    ufw-docker--add-rule  instance-name  172.19.0.7  8080  tcp  awesomenet
    ufw-docker--add-rule  instance-name  172.19.0.7  5353  udp  awesomenet
}


test-IPv6-ufw-docker--allow-instance-and-match-the-port() {
    setup-IPv6-ufw-docker--allow

    ufw-docker--allow instance-name 5000 tcp
}
test-IPv6-ufw-docker--allow-instance-and-match-the-port-assert() {
    ufw-docker--add-rule instance-name 172.18.0.3 5000 tcp default
    ufw-docker--add-rule instance-name/v6 fd00:cf::42 5000 tcp default
}


test-IPv6-ufw-docker--allow-instance-all-published-port() {
    setup-IPv6-ufw-docker--allow

    ufw-docker--allow instance-name "" ""
}
test-IPv6-ufw-docker--allow-instance-all-published-port-assert() {
    ufw-docker--add-rule instance-name 172.18.0.3 5000 tcp default
    ufw-docker--add-rule instance-name/v6 fd00:cf::42 5000 tcp default
    ufw-docker--add-rule instance-name 172.18.0.3 8080 tcp default
    ufw-docker--add-rule instance-name/v6 fd00:cf::42 8080 tcp default
    ufw-docker--add-rule instance-name 172.18.0.3 5353 udp default
    ufw-docker--add-rule instance-name/v6 fd00:cf::42 5353 udp default
}


test-IPv6-ufw-docker--allow-instance-all-published-tcp-port() {
    setup-IPv6-ufw-docker--allow

    ufw-docker--allow instance-name "" tcp
}
test-IPv6-ufw-docker--allow-instance-all-published-tcp-port-assert() {
    ufw-docker--add-rule instance-name 172.18.0.3 5000 tcp default
    ufw-docker--add-rule instance-name/v6 fd00:cf::42 5000 tcp default
    ufw-docker--add-rule instance-name 172.18.0.3 8080 tcp default
    ufw-docker--add-rule instance-name/v6 fd00:cf::42 8080 tcp default
    ufw-docker--add-rule instance-name 172.18.0.3 5353 udp default # FIXME
    ufw-docker--add-rule instance-name/v6 fd00:cf::42 5353 udp default # FIXME
}


test-IPv6-ufw-docker--allow-instance-all-published-port-multinetwork() {
    setup-IPv6-ufw-docker--allow--multinetwork

    ufw-docker--allow instance-name "" ""
}
test-IPv6-ufw-docker--allow-instance-all-published-port-multinetwork-assert() {
    ufw-docker--add-rule  instance-name  172.18.0.3  5000  tcp  default
    ufw-docker--add-rule instance-name/v6 fd00:cf::42 5000 tcp default
    ufw-docker--add-rule  instance-name  172.19.0.7  5000  tcp  awesomenet
    ufw-docker--add-rule instance-name/v6 fd00:cf::207 5000 tcp awesomenet
    ufw-docker--add-rule  instance-name  172.18.0.3  8080  tcp  default
    ufw-docker--add-rule instance-name/v6 fd00:cf::42 8080 tcp default
    ufw-docker--add-rule  instance-name  172.19.0.7  8080  tcp  awesomenet
    ufw-docker--add-rule instance-name/v6 fd00:cf::207 8080 tcp awesomenet
    ufw-docker--add-rule  instance-name  172.18.0.3  5353  udp  default
    ufw-docker--add-rule instance-name/v6 fd00:cf::42 5353 udp default
    ufw-docker--add-rule  instance-name  172.19.0.7  5353  udp  awesomenet
    ufw-docker--add-rule instance-name/v6 fd00:cf::207 5353 udp awesomenet
}

test-IPv6-ufw-docker--allow-instance-all-published-port-multinetwork-select-network() {
    setup-IPv6-ufw-docker--allow--multinetwork

    ufw-docker--allow instance-name "" "" awesomenet
}
test-IPv6-ufw-docker--allow-instance-all-published-port-multinetwork-select-network-assert() {
    ufw-docker--add-rule  instance-name  172.19.0.7  5000  tcp  awesomenet
    ufw-docker--add-rule instance-name/v6 fd00:cf::207 5000 tcp awesomenet
    ufw-docker--add-rule  instance-name  172.19.0.7  8080  tcp  awesomenet
    ufw-docker--add-rule instance-name/v6 fd00:cf::207 8080 tcp awesomenet
    ufw-docker--add-rule  instance-name  172.19.0.7  5353  udp  awesomenet
    ufw-docker--add-rule instance-name/v6 fd00:cf::207 5353 udp awesomenet
}


test-ufw-docker--add-rule-a-non-existing-rule() {
    @mockfalse ufw-docker--list webapp 5000 tcp ""
    @ignore echo

    load-ufw-docker-function ufw-docker--add-rule
    ufw-docker--add-rule webapp 172.18.0.4 5000 tcp
}
test-ufw-docker--add-rule-a-non-existing-rule-assert() {
    ufw route allow proto tcp from any to 172.18.0.4 port 5000 comment "allow webapp 5000/tcp"
}

test-ufw-docker--add-rule-a-non-existing-rule-with-network() {
    @mockfalse ufw-docker--list webapp 5000 tcp default
    @ignore echo

    load-ufw-docker-function ufw-docker--add-rule
    ufw-docker--add-rule webapp 172.18.0.4 5000 tcp default
}
test-ufw-docker--add-rule-a-non-existing-rule-with-network-assert() {
    ufw route allow proto tcp from any to 172.18.0.4 port 5000 comment "allow webapp 5000/tcp default"
}


test-ufw-docker--add-rule-modify-an-existing-rule() {
    @mocktrue ufw-docker--list webapp 5000 tcp default
    @mock ufw --dry-run route allow proto tcp from any to 172.18.0.4 port 5000 comment "allow webapp 5000/tcp default" === @echo
    @mockfalse grep "^Skipping"
    @ignore echo

    load-ufw-docker-function ufw-docker--add-rule
    ufw-docker--add-rule webapp 172.18.0.4 5000 tcp default
}
test-ufw-docker--add-rule-modify-an-existing-rule-assert() {
    ufw-docker--delete webapp 5000 tcp default

    ufw route allow proto tcp from any to 172.18.0.4 port 5000 comment "allow webapp 5000/tcp default"
}


test-IPv6-ufw-docker--add-rule-modify-an-existing-rule() {
    @mocktrue ufw-docker--list webapp/v6 5000 tcp default
    @mock ufw --dry-run route allow proto tcp from any to fd00:cf::42 port 5000 comment "allow webapp/v6 5000/tcp default" === @echo
    @mockfalse grep "^Skipping"
    @ignore echo

    load-ufw-docker-function ufw-docker--add-rule
    ufw-docker--add-rule webapp/v6 fd00:cf::42 5000 tcp default
}
test-IPv6-ufw-docker--add-rule-modify-an-existing-rule-assert() {
    ufw-docker--delete webapp/v6 5000 tcp default

    ufw route allow proto tcp from any to fd00:cf::42 port 5000 comment "allow webapp/v6 5000/tcp default"
}


test-ufw-docker--add-rule-skip-an-existing-rule() {
    @mocktrue ufw-docker--list webapp 5000 tcp ""
    @mocktrue ufw --dry-run route allow proto tcp from any to 172.18.0.4 port 5000 comment "allow webapp 5000/tcp"
    @mocktrue grep "^Skipping"
    @ignore echo

    load-ufw-docker-function ufw-docker--add-rule
    ufw-docker--add-rule webapp 172.18.0.4 5000 tcp ""
}
test-ufw-docker--add-rule-skip-an-existing-rule-assert() {
    @do-nothing
}


test-ufw-docker--add-rule-modify-an-existing-rule-without-port() {
    @mocktrue ufw-docker--list webapp "" tcp ""
    @mock ufw --dry-run route allow proto tcp from any to 172.18.0.4 comment "allow webapp" === @echo
    @mockfalse grep "^Skipping"
    @ignore echo

    load-ufw-docker-function ufw-docker--add-rule

    ufw-docker--add-rule webapp 172.18.0.4 "" tcp ""
}
test-ufw-docker--add-rule-modify-an-existing-rule-without-port-assert() {
    ufw-docker--delete webapp "" tcp ""

    ufw route allow proto tcp from any to 172.18.0.4 comment "allow webapp"
}


test-ufw-docker--instance-name-found-a-name() {
    @mock docker inspect --format="{{.Name}}" foo
    @mock sed -e 's,^/,,'
    @mockfalse grep "^$GREP_REGEXP_NAME\$"

    @mock echo -n foo

    load-ufw-docker-function ufw-docker--instance-name
    ufw-docker--instance-name foo
}
test-ufw-docker--instance-name-found-a-name-assert() {
    docker inspect --format="{{.Name}}" foo
    @dryrun echo -n foo
}


test-ufw-docker--instance-name-found-an-id() {
    @mock docker inspect --format="{{.Name}}" fooid
    @mock sed -e 's,^/,,'
    @mockfalse grep "^$GREP_REGEXP_NAME\$"
    @mock echo -n fooid

    load-ufw-docker-function ufw-docker--instance-name
    ufw-docker--instance-name fooid
}
test-ufw-docker--instance-name-found-an-id-assert() {
    docker inspect --format="{{.Name}}" fooid
    @dryrun echo -n fooid
}

function mock-ufw-status-numbered-foo() {
    @mock ufw status numbered === @echo "Status: active

     To                         Action      From
     --                         ------      ----
[ 1] OpenSSH                    ALLOW IN    Anywhere
[ 2] Anywhere                   ALLOW IN    192.168.56.128/28
[ 3] 172.17.0.3 80/tcp          ALLOW FWD   Anywhere                   # allow foo 80/tcp bridge
[ 4] 172.20.0.3 80/tcp          ALLOW FWD   Anywhere                   # allow bar 80/tcp bar-external
[ 5] 172.17.0.3 53/udp          ALLOW FWD   Anywhere                   # allow foo 53/udp foo-internal
[ 6] 172.17.0.3 53/tcp          ALLOW FWD   Anywhere                   # allow foo 53/tcp
[ 7] 172.18.0.2 29090/tcp       ALLOW FWD   Anywhere                   # allow id111111 29090/tcp
[ 8] 172.18.0.2 48080/tcp       ALLOW FWD   Anywhere                   # allow id222222 48080/tcp
[ 9] 172.18.0.2 40080/tcp       ALLOW FWD   Anywhere                   # allow id333333 40080/tcp
[10] OpenSSH (v6)               ALLOW IN    Anywhere (v6)
[11] Anywhere (v6)              ALLOW IN    fd00:a:b:0:cafe::/80
[12] fd00:a:b:deaf::3 80/tcp    ALLOW FWD   Anywhere (v6)              # allow foo/v6 80/tcp bridge
[13] fd05:8f23:c937:2::3 80/tcp ALLOW FWD   Anywhere (v6)              # allow bar/v6 80/tcp bar-external
[14] fd00:a:b:deaf::3 53/udp    ALLOW FWD   Anywhere (v6)              # allow foo/v6 53/udp foo-internal
[15] fd00:a:b:deaf::3 53/tcp    ALLOW FWD   Anywhere (v6)              # allow foo/v6 53/tcp
"

}

test-ufw-docker--status() {
    mock-ufw-status-numbered-foo
    @allow-real grep '# allow [-_.[:alnum:]]\+\(/v6\)\?\( [[:digit:]]\+/\(tcp\|udp\)\( [-_.[:alnum:]]\+\)\?\)\?$'

    load-ufw-docker-function ufw-docker--list
    load-ufw-docker-function ufw-docker--status
    ufw-docker--status
}
test-ufw-docker--status-assert() {
    test-ufw-docker--list-all-assert
}

test-ufw-docker--list-all() {
    mock-ufw-status-numbered-foo
    @allow-real grep '# allow [-_.[:alnum:]]\+\(/v6\)\?\( [[:digit:]]\+/\(tcp\|udp\)\( [-_.[:alnum:]]\+\)\?\)\?$'

    load-ufw-docker-function ufw-docker--list
    ufw-docker--list
}
test-ufw-docker--list-all-assert() {
    @stdout "[ 3] 172.17.0.3 80/tcp          ALLOW FWD   Anywhere                   # allow foo 80/tcp bridge"
    @stdout "[ 4] 172.20.0.3 80/tcp          ALLOW FWD   Anywhere                   # allow bar 80/tcp bar-external"
    @stdout "[ 5] 172.17.0.3 53/udp          ALLOW FWD   Anywhere                   # allow foo 53/udp foo-internal"
    @stdout "[ 6] 172.17.0.3 53/tcp          ALLOW FWD   Anywhere                   # allow foo 53/tcp"
    @stdout "[ 7] 172.18.0.2 29090/tcp       ALLOW FWD   Anywhere                   # allow id111111 29090/tcp"
    @stdout "[ 8] 172.18.0.2 48080/tcp       ALLOW FWD   Anywhere                   # allow id222222 48080/tcp"
    @stdout "[ 9] 172.18.0.2 40080/tcp       ALLOW FWD   Anywhere                   # allow id333333 40080/tcp"
    @stdout "[12] fd00:a:b:deaf::3 80/tcp    ALLOW FWD   Anywhere (v6)              # allow foo/v6 80/tcp bridge"
    @stdout "[13] fd05:8f23:c937:2::3 80/tcp ALLOW FWD   Anywhere (v6)              # allow bar/v6 80/tcp bar-external"
    @stdout "[14] fd00:a:b:deaf::3 53/udp    ALLOW FWD   Anywhere (v6)              # allow foo/v6 53/udp foo-internal"
    @stdout "[15] fd00:a:b:deaf::3 53/tcp    ALLOW FWD   Anywhere (v6)              # allow foo/v6 53/tcp"
}

test-ufw-docker--list-name() {
    mock-ufw-status-numbered-foo
    @allow-real grep '# allow foo\(/v6\)\?\( [[:digit:]]\+/\(tcp\|udp\)\( [-_.[:alnum:]]\+\)\?\)\?$'

    load-ufw-docker-function ufw-docker--list
    ufw-docker--list foo
}
test-ufw-docker--list-name-assert() {
    @stdout "[ 3] 172.17.0.3 80/tcp          ALLOW FWD   Anywhere                   # allow foo 80/tcp bridge"
    @stdout "[ 5] 172.17.0.3 53/udp          ALLOW FWD   Anywhere                   # allow foo 53/udp foo-internal"
    @stdout "[ 6] 172.17.0.3 53/tcp          ALLOW FWD   Anywhere                   # allow foo 53/tcp"
    @stdout "[12] fd00:a:b:deaf::3 80/tcp    ALLOW FWD   Anywhere (v6)              # allow foo/v6 80/tcp bridge"
    @stdout "[14] fd00:a:b:deaf::3 53/udp    ALLOW FWD   Anywhere (v6)              # allow foo/v6 53/udp foo-internal"
    @stdout "[15] fd00:a:b:deaf::3 53/tcp    ALLOW FWD   Anywhere (v6)              # allow foo/v6 53/tcp"
}

test-ufw-docker--list-name-udp() {
    mock-ufw-status-numbered-foo
    @allow-real grep '# allow foo\(/v6\)\? [[:digit:]]\+/udp\( [-_.[:alnum:]]\+\)\?$'

    load-ufw-docker-function ufw-docker--list
    ufw-docker--list foo "" udp
}
test-ufw-docker--list-name-udp-assert() {
    @stdout "[ 5] 172.17.0.3 53/udp          ALLOW FWD   Anywhere                   # allow foo 53/udp foo-internal"
    @stdout "[14] fd00:a:b:deaf::3 53/udp    ALLOW FWD   Anywhere (v6)              # allow foo/v6 53/udp foo-internal"
}


test-ufw-docker--list-name-80-_-bridge() {
    mock-ufw-status-numbered-foo
    @allow-real grep '# allow foo\(/v6\)\? 80/tcp bridge$'

    load-ufw-docker-function ufw-docker--list
    ufw-docker--list foo 80 "" bridge
}
test-ufw-docker--list-name-80-_-bridge-assert() {
    @stdout "[ 3] 172.17.0.3 80/tcp          ALLOW FWD   Anywhere                   # allow foo 80/tcp bridge"
    @stdout "[12] fd00:a:b:deaf::3 80/tcp    ALLOW FWD   Anywhere (v6)              # allow foo/v6 80/tcp bridge"
}


test-ufw-docker--list-name-53-udp() {
    mock-ufw-status-numbered-foo
    @allow-real grep '# allow foo\(/v6\)\? 53/udp\( [-_.[:alnum:]]\+\)\?$'

    load-ufw-docker-function ufw-docker--list
    ufw-docker--list foo 53 udp
}
test-ufw-docker--list-name-53-udp-assert() {
    @stdout "[ 5] 172.17.0.3 53/udp          ALLOW FWD   Anywhere                   # allow foo 53/udp foo-internal"
    @stdout "[14] fd00:a:b:deaf::3 53/udp    ALLOW FWD   Anywhere (v6)              # allow foo/v6 53/udp foo-internal"
}


test-ufw-docker--list-grep-with-incorrect-network() {
    mock-ufw-status-numbered-foo
    @allow-real grep '# allow foo\(/v6\)\? 53/udp incorrect-network$'

    load-ufw-docker-function ufw-docker--list
    ufw-docker--list foo 53 udp incorrect-network
}
test-ufw-docker--list-grep-with-incorrect-network-assert() {
    @fail
}


test-ufw-docker--list-foo-80-_-_() {
    mock-ufw-status-numbered-foo
    @allow-real grep '# allow foo\(/v6\)\? 80/tcp\( [-_.[:alnum:]]\+\)\?$'

    load-ufw-docker-function ufw-docker--list
    ufw-docker--list foo 80
}
test-ufw-docker--list-foo-80-_-_-assert() {
    @stdout "[ 3] 172.17.0.3 80/tcp          ALLOW FWD   Anywhere                   # allow foo 80/tcp bridge"
    @stdout "[12] fd00:a:b:deaf::3 80/tcp    ALLOW FWD   Anywhere (v6)              # allow foo/v6 80/tcp bridge"
}


test-ufw-docker--list-number() {
    @mocktrue ufw-docker--list foo 53 udp

    load-ufw-docker-function ufw-docker--list-number
    ufw-docker--list-number foo 53 udp
}
test-ufw-docker--list-number-assert() {
    sed -e 's/^\[[[:blank:]]*\([[:digit:]]\+\)\].*/\1/'
}


test-ufw-docker--delete-empty-result() {
    @mock ufw-docker--list-number webapp 80 tcp === @stdout ""
    @mockpipe sort -rn

    load-ufw-docker-function ufw-docker--delete
    ufw-docker--delete webapp 80 tcp
}
test-ufw-docker--delete-empty-result-assert() {
    @do-nothing
}


test-ufw-docker--delete-all() {
    @mock ufw-docker--list-number webapp 80 tcp === @stdout 5 8 9
    @mockpipe sort -rn
    @ignore echo

    load-ufw-docker-function ufw-docker--delete
    ufw-docker--delete webapp 80 tcp
}
test-ufw-docker--delete-all-assert() {
    ufw delete 5
    ufw delete 8
    ufw delete 9
}

test-ufw-docker--check-install_ipv4() {
    @mock mktemp === @stdout /tmp/after_rules_tmp
    @mock sed "/^# BEGIN UFW AND DOCKER/,/^# END UFW AND DOCKER/d" /etc/ufw/after.rules
    @mock tee "/tmp/after_rules_tmp"
    @capture tee -a /tmp/after_rules_tmp
    @allow-real cat

    load-ufw-docker-function ufw-docker--check-install
    ufw-docker--check-install
}
test-ufw-docker--check-install_ipv4-assert() {
    rm-on-exit /tmp/after_rules_tmp
    sed "/^# BEGIN UFW AND DOCKER/,/^# END UFW AND DOCKER/d" /etc/ufw/after.rules
    @assert-capture tee -a /tmp/after_rules_tmp <<\EOF
# BEGIN UFW AND DOCKER
*filter
:ufw-user-forward - [0:0]
:ufw-docker-logging-deny - [0:0]
:DOCKER-USER - [0:0]
-A DOCKER-USER -j ufw-user-forward

-A DOCKER-USER -j RETURN -s 10.0.0.0/8
-A DOCKER-USER -j RETURN -s 172.16.0.0/12
-A DOCKER-USER -j RETURN -s 192.168.0.0/16

-A DOCKER-USER -p udp -m udp --sport 53 --dport 1024:65535 -j RETURN

-A DOCKER-USER -j ufw-docker-logging-deny -p tcp -m tcp --tcp-flags FIN,SYN,RST,ACK SYN -d 10.0.0.0/8
-A DOCKER-USER -j ufw-docker-logging-deny -p tcp -m tcp --tcp-flags FIN,SYN,RST,ACK SYN -d 172.16.0.0/12
-A DOCKER-USER -j ufw-docker-logging-deny -p tcp -m tcp --tcp-flags FIN,SYN,RST,ACK SYN -d 192.168.0.0/16
-A DOCKER-USER -j ufw-docker-logging-deny -p udp -m udp --dport 0:32767 -d 10.0.0.0/8
-A DOCKER-USER -j ufw-docker-logging-deny -p udp -m udp --dport 0:32767 -d 172.16.0.0/12
-A DOCKER-USER -j ufw-docker-logging-deny -p udp -m udp --dport 0:32767 -d 192.168.0.0/16

-A DOCKER-USER -j RETURN

-A ufw-docker-logging-deny -m limit --limit 3/min --limit-burst 10 -j LOG --log-prefix "[UFW DOCKER BLOCK] "
-A ufw-docker-logging-deny -j DROP

COMMIT
# END UFW AND DOCKER
EOF
    diff -u --color=auto /etc/ufw/after.rules /tmp/after_rules_tmp
}

test-ufw-docker--check-install_ipv4-subnets() {
    @mock ufw-docker--list-docker-subnets IPv4 192.168.56.128/28 172.16.0.0/12 === @stdout "172.16.0.0/12" "192.168.56.128/28"
    @mock mktemp === @stdout /tmp/after_rules_tmp
    @mock sed "/^# BEGIN UFW AND DOCKER/,/^# END UFW AND DOCKER/d" /etc/ufw/after.rules
    @mock tee "/tmp/after_rules_tmp"
    @capture tee -a /tmp/after_rules_tmp
    @allow-real cat

    load-ufw-docker-function ufw-docker--check-install
    ufw-docker--check-install --docker-subnets 192.168.56.128/28 172.16.0.0/12
}
test-ufw-docker--check-install_ipv4-subnets-assert() {
    rm-on-exit /tmp/after_rules_tmp
    sed "/^# BEGIN UFW AND DOCKER/,/^# END UFW AND DOCKER/d" /etc/ufw/after.rules
    @assert-capture tee -a /tmp/after_rules_tmp <<\EOF
# BEGIN UFW AND DOCKER
*filter
:ufw-user-forward - [0:0]
:ufw-docker-logging-deny - [0:0]
:DOCKER-USER - [0:0]
-A DOCKER-USER -j ufw-user-forward

-A DOCKER-USER -j RETURN -s 172.16.0.0/12
-A DOCKER-USER -j RETURN -s 192.168.56.128/28

-A DOCKER-USER -p udp -m udp --sport 53 --dport 1024:65535 -j RETURN

-A DOCKER-USER -j ufw-docker-logging-deny -p tcp -m tcp --tcp-flags FIN,SYN,RST,ACK SYN -d 172.16.0.0/12
-A DOCKER-USER -j ufw-docker-logging-deny -p tcp -m tcp --tcp-flags FIN,SYN,RST,ACK SYN -d 192.168.56.128/28
-A DOCKER-USER -j ufw-docker-logging-deny -p udp -m udp --dport 0:32767 -d 172.16.0.0/12
-A DOCKER-USER -j ufw-docker-logging-deny -p udp -m udp --dport 0:32767 -d 192.168.56.128/28

-A DOCKER-USER -j RETURN

-A ufw-docker-logging-deny -m limit --limit 3/min --limit-burst 10 -j LOG --log-prefix "[UFW DOCKER BLOCK] "
-A ufw-docker-logging-deny -j DROP

COMMIT
# END UFW AND DOCKER
EOF
    diff -u --color=auto /etc/ufw/after.rules /tmp/after_rules_tmp
}
