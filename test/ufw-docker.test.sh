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

    @mock man-page === @stdout "MAN PAGE FOR UFW-DOCKER"

    @allow-real sort
}

function ufw-docker() {
    @source <(@sed -n '/^# __main__$/,$p' "$working_dir/../ufw-docker") "$@"
}

function load-ufw-docker-function() {
    set -euo pipefail
    @load_function "$working_dir/../ufw-docker" "$1"
}

test-init-with-legacy-iptables() {
    @mocktrue grep -F '(legacy)'
    @source <(@sed '/PATH=/d' "$working_dir/../ufw-docker") help
}
test-init-with-legacy-iptables-assert() {
    iptables --version
    test -n chaifeng/ufw-docker-agent:090502-legacy
    trap on-exit EXIT INT TERM QUIT ABRT ERR
    @dryrun cat
}


test-init-with-nf-tables-iptables() {
    @mockfalse grep -F '(legacy)'
    @source <(@sed '/PATH=/d' "$working_dir/../ufw-docker") help
}
test-init-with-nf-tables-iptables-assert() {
    iptables --version
    test -n chaifeng/ufw-docker-agent:090502-nf_tables
    trap on-exit EXIT INT TERM QUIT ABRT ERR
    @dryrun cat
}


test-init-with-custom-agent-image() {
    UFW_DOCKER_AGENT_IMAGE=chaifeng/ufw-docker-agent:100917
    @source <(@sed '/PATH=/d' "$working_dir/../ufw-docker") help
}
test-init-with-custom-agent-image-assert() {
    test -n chaifeng/ufw-docker-agent:100917
    trap on-exit EXIT INT TERM QUIT ABRT ERR
    @dryrun cat
}


test-help-command() {
    ufw-docker help
}
test-help-command-assert() {
    ufw-docker--help
}


test-script-called-without-parameters-shows-help() {
    ufw-docker
}
test-script-called-without-parameters-shows-help-assert() {
    test-help-command-assert
}


test-script-fails-if-ufw-is-disabled() {
    @mockfalse grep -Fq "Status: active"
    @mock iptables --version === @stdout 'iptables v1.8.4 (legacy)'

    ufw-docker
}
test-script-fails-if-ufw-is-disabled-assert() {
    die "UFW is disabled or you are not root user, or mismatched iptables legacy/nf_tables, current iptables v1.8.4 (legacy)"
    ufw-docker--help
}


test-script-fails-if-docker-is-not-installed() {
    @mockfalse docker -v

    ufw-docker
}
test-script-fails-if-docker-is-not-installed-assert() {
    die "Docker executable not found."
    ufw-docker--help
}


test-status-command() {
    ufw-docker status
}
test-status-command-assert() {
    ufw-docker--status
}


test-install-command() {
    ufw-docker install
}
test-install-command-assert() {
    ufw-docker--install
}


test-install-command-with-docker-subnets() {
    ufw-docker install --docker-subnets
}
test-install-command-with-docker-subnets-assert() {
    ufw-docker--install --docker-subnets
}


test-check-command() {
    ufw-docker check
}
test-check-command-assert() {
    ufw-docker--check
}


test-check-command-with-docker-subnets() {
    ufw-docker check --docker-subnets
}
test-check-command-with-docker-subnets-assert() {
    ufw-docker--check --docker-subnets
}


test-service-command() {
    ufw-docker service allow httpd
}
test-service-command-assert() {
    ufw-docker--service allow httpd
}


test-raw-command() {
    ufw-docker raw-command status
}
test-raw-command-assert() {
    ufw-docker--raw-command status
}


test-add-service-rule-command() {
    ufw-docker add-service-rule httpd 80/tcp
}
test-add-service-rule-command-assert() {
    ufw-docker--add-service-rule httpd 80/tcp
}


test-ASSERT-FAIL-delete-must-have-parameters() {
    ufw-docker delete
}


test-ASSERT-FAIL-list-must-have-parameters() {
    ufw-docker list
}


test-ASSERT-FAIL-allow-must-have-parameters() {
    ufw-docker allow
}


test-ASSERT-FAIL-delete-httpd-but-it-doesnt-exist() {
    @mockfalse ufw-docker--instance-name httpd
    ufw-docker delete httpd
}


test-ASSERT-FAIL-list-httpd-but-it-doesnt-exist() {
    @mockfalse ufw-docker--instance-name httpd
    ufw-docker list httpd
}


test-ASSERT-FAIL-allow-httpd-but-it-doesnt-exist() {
    @mockfalse ufw-docker--instance-name httpd
    ufw-docker allow httpd
}


test-list-command-for-instance() {
    @mock ufw-docker--instance-name httpd === @stdout httpd-container-name
    ufw-docker list httpd
}
test-list-command-for-instance-assert() {
    ufw-docker--list httpd-container-name "" tcp ""
}


test-allow-command-for-instance() {
    @mock ufw-docker--instance-name httpd === @stdout httpd-container-name
    ufw-docker allow httpd
}
test-allow-command-for-instance-assert() {
    ufw-docker--allow httpd-container-name "" tcp ""
}


test-allow-command-for-instance-with-port() {
    @mock ufw-docker--instance-name httpd === @stdout httpd-container-name
    ufw-docker allow httpd 80
}
test-allow-command-for-instance-with-port-assert() {
    ufw-docker--allow httpd-container-name 80 tcp ""
}


test-allow-command-for-instance-with-port-and-tcp-protocol() {
    @mock ufw-docker--instance-name httpd === @stdout httpd-container-name
    ufw-docker allow httpd 80/tcp
}
test-allow-command-for-instance-with-port-and-tcp-protocol-assert() {
    ufw-docker--allow httpd-container-name 80 tcp ""
}


test-allow-command-for-instance-with-port-and-udp-protocol() {
    @mock ufw-docker--instance-name httpd === @stdout httpd-container-name
    ufw-docker allow httpd 80/udp
}
test-allow-command-for-instance-with-port-and-udp-protocol-assert() {
    ufw-docker--allow httpd-container-name 80 udp ""
}


test-ASSERT-FAIL-allow-httpd-INVALID-port() {
    @mock ufw-docker--instance-name httpd === @stdout httpd-container-name
    @mock die 'invalid port syntax: "invalid".' === exit 1

    ufw-docker allow httpd invalid
}


test-delete-allow-command-for-instance() {
    @mock ufw-docker--instance-name httpd === @stdout httpd-container-name
    ufw-docker delete allow httpd
}
test-delete-allow-command-for-instance-assert() {
    ufw-docker--delete httpd-container-name "" tcp ""
}


test-ASSERT-FAIL-delete-only-supports-allowed-rules() {
    @mock ufw-docker--instance-name httpd === @stdout httpd-container-name
    ufw-docker delete non-allow
}
test-ASSERT-FAIL-delete-only-supports-allowed-rules-assert() {
    die "\"delete\" command only support removing allowed rules"
}


function setup-ufw-docker--allow() {
    load-ufw-docker-function ufw-docker--allow

    @mocktrue docker inspect instance-name
    @mock docker inspect --format '{{range $name, $net := .NetworkSettings.Networks}}{{if $net.IPAddress|len}}{{$name}} {{$net.IPAddress}}{{"\n"}}{{end}}{{if $net.GlobalIPv6Address|len}}{{$name}} {{$net.GlobalIPv6Address}}{{"\n"}}{{end}}{{end}}' instance-name === @stdout "default 172.18.0.3"
    @mock docker inspect --format='{{range $p, $conf := .NetworkSettings.Ports}}{{with $conf}}{{$p}}{{"\n"}}{{end}}{{end}}' instance-name === @stdout 5000/tcp 8080/tcp 5353/udp
}

function setup-IPv6-ufw-docker--allow() {
    load-ufw-docker-function ufw-docker--allow

    @mocktrue docker inspect instance-name
    @mock docker inspect --format '{{range $name, $net := .NetworkSettings.Networks}}{{if $net.IPAddress|len}}{{$name}} {{$net.IPAddress}}{{"\n"}}{{end}}{{if $net.GlobalIPv6Address|len}}{{$name}} {{$net.GlobalIPv6Address}}{{"\n"}}{{end}}{{end}}' instance-name === @stdout "default 172.18.0.3" "default fd00:cf::42"
    @mock docker inspect --format='{{range $p, $conf := .NetworkSettings.Ports}}{{with $conf}}{{$p}}{{"\n"}}{{end}}{{end}}' instance-name === @stdout 5000/tcp 8080/tcp 5353/udp
}

function setup-ufw-docker--allow--multinetwork() {
    load-ufw-docker-function ufw-docker--allow

    @mocktrue docker inspect instance-name
    @mock docker inspect --format '{{range $name, $net := .NetworkSettings.Networks}}{{if $net.IPAddress|len}}{{$name}} {{$net.IPAddress}}{{"\n"}}{{end}}{{if $net.GlobalIPv6Address|len}}{{$name}} {{$net.GlobalIPv6Address}}{{"\n"}}{{end}}{{end}}' instance-name === @stdout "default 172.18.0.3" "awesomenet 172.19.0.7"
    @mock docker inspect --format='{{range $p, $conf := .NetworkSettings.Ports}}{{with $conf}}{{$p}}{{"\n"}}{{end}}{{end}}' instance-name === @stdout 5000/tcp 8080/tcp 5353/udp
}

function setup-IPv6-ufw-docker--allow--multinetwork() {
    load-ufw-docker-function ufw-docker--allow

    @mocktrue docker inspect instance-name
    @mock docker inspect --format '{{range $name, $net := .NetworkSettings.Networks}}{{if $net.IPAddress|len}}{{$name}} {{$net.IPAddress}}{{"\n"}}{{end}}{{if $net.GlobalIPv6Address|len}}{{$name}} {{$net.GlobalIPv6Address}}{{"\n"}}{{end}}{{end}}' instance-name === @stdout "default 172.18.0.3" "default fd00:cf::42" "awesomenet 172.19.0.7" "awesomenet fd00:cf::207"
    @mock docker inspect --format='{{range $p, $conf := .NetworkSettings.Ports}}{{with $conf}}{{$p}}{{"\n"}}{{end}}{{end}}' instance-name === @stdout 5000/tcp 8080/tcp 5353/udp
}


test-allow-internal-fails-for-non-existent-instance() {
    setup-ufw-docker--allow

    @mockfalse docker inspect invalid-instance
    @mockfalse die "Docker instance \"invalid-instance\" doesn't exist."

    ufw-docker--allow invalid-instance 80 tcp
}
test-allow-internal-fails-for-non-existent-instance-assert() {
    @do-nothing
    @fail
}


test-allow-internal-fails-when-port-does-not-match() {
    setup-ufw-docker--allow

    ufw-docker--allow instance-name 80 tcp
}
test-allow-internal-fails-when-port-does-not-match-assert() {
    @do-nothing
    @fail
}


test-allow-internal-fails-when-protocol-does-not-match() {
    setup-ufw-docker--allow

    ufw-docker--allow instance-name 5353 tcp
}
test-allow-internal-fails-when-protocol-does-not-match-assert() {
    @do-nothing
    @fail
}


test-allow-internal-succeeds-when-port-matches() {
    setup-ufw-docker--allow

    ufw-docker--allow instance-name 5000 tcp
}
test-allow-internal-succeeds-when-port-matches-assert() {
    ufw-docker--add-rule instance-name 172.18.0.3 5000 tcp default
}


test-allow-internal-succeeds-for-all-published-ports() {
    setup-ufw-docker--allow

    ufw-docker--allow instance-name "" ""
}
test-allow-internal-succeeds-for-all-published-ports-assert() {
    ufw-docker--add-rule instance-name 172.18.0.3 5000 tcp default
    ufw-docker--add-rule instance-name 172.18.0.3 8080 tcp default
    ufw-docker--add-rule instance-name 172.18.0.3 5353 udp default
}


test-allow-internal-succeeds-for-all-published-tcp-ports() {
    setup-ufw-docker--allow

    ufw-docker--allow instance-name "" tcp
}
test-allow-internal-succeeds-for-all-published-tcp-ports-assert() {
    ufw-docker--add-rule instance-name 172.18.0.3 5000 tcp default
    ufw-docker--add-rule instance-name 172.18.0.3 8080 tcp default
    ufw-docker--add-rule instance-name 172.18.0.3 5353 udp default # FIXME
}


test-allow-internal-succeeds-for-all-published-ports-on-multinetwork() {
    setup-ufw-docker--allow--multinetwork

    ufw-docker--allow instance-name "" ""
}
test-allow-internal-succeeds-for-all-published-ports-on-multinetwork-assert() {
    ufw-docker--add-rule  instance-name  172.18.0.3  5000  tcp  default
    ufw-docker--add-rule  instance-name  172.19.0.7  5000  tcp  awesomenet
    ufw-docker--add-rule  instance-name  172.18.0.3  8080  tcp  default
    ufw-docker--add-rule  instance-name  172.19.0.7  8080  tcp  awesomenet
    ufw-docker--add-rule  instance-name  172.18.0.3  5353  udp  default
    ufw-docker--add-rule  instance-name  172.19.0.7  5353  udp  awesomenet
}

test-allow-internal-succeeds-for-all-published-ports-on-selected-multinetwork() {
    setup-ufw-docker--allow--multinetwork

    ufw-docker--allow instance-name "" "" awesomenet
}
test-allow-internal-succeeds-for-all-published-ports-on-selected-multinetwork-assert() {
    ufw-docker--add-rule  instance-name  172.19.0.7  5000  tcp  awesomenet
    ufw-docker--add-rule  instance-name  172.19.0.7  8080  tcp  awesomenet
    ufw-docker--add-rule  instance-name  172.19.0.7  5353  udp  awesomenet
}


test-ipv6-allow-internal-succeeds-when-port-matches() {
    setup-IPv6-ufw-docker--allow

    ufw-docker--allow instance-name 5000 tcp
}
test-ipv6-allow-internal-succeeds-when-port-matches-assert() {
    ufw-docker--add-rule instance-name 172.18.0.3 5000 tcp default
    ufw-docker--add-rule instance-name/v6 fd00:cf::42 5000 tcp default
}


test-ipv6-allow-internal-succeeds-for-all-published-ports() {
    setup-IPv6-ufw-docker--allow

    ufw-docker--allow instance-name "" ""
}
test-ipv6-allow-internal-succeeds-for-all-published-ports-assert() {
    ufw-docker--add-rule instance-name 172.18.0.3 5000 tcp default
    ufw-docker--add-rule instance-name/v6 fd00:cf::42 5000 tcp default
    ufw-docker--add-rule instance-name 172.18.0.3 8080 tcp default
    ufw-docker--add-rule instance-name/v6 fd00:cf::42 8080 tcp default
    ufw-docker--add-rule instance-name 172.18.0.3 5353 udp default
    ufw-docker--add-rule instance-name/v6 fd00:cf::42 5353 udp default
}


test-ipv6-allow-internal-succeeds-for-all-published-tcp-ports() {
    setup-IPv6-ufw-docker--allow

    ufw-docker--allow instance-name "" tcp
}
test-ipv6-allow-internal-succeeds-for-all-published-tcp-ports-assert() {
    ufw-docker--add-rule instance-name 172.18.0.3 5000 tcp default
    ufw-docker--add-rule instance-name/v6 fd00:cf::42 5000 tcp default
    ufw-docker--add-rule instance-name 172.18.0.3 8080 tcp default
    ufw-docker--add-rule instance-name/v6 fd00:cf::42 8080 tcp default
    ufw-docker--add-rule instance-name 172.18.0.3 5353 udp default # FIXME
    ufw-docker--add-rule instance-name/v6 fd00:cf::42 5353 udp default # FIXME
}


test-ipv6-allow-internal-succeeds-for-all-published-ports-on-multinetwork() {
    setup-IPv6-ufw-docker--allow--multinetwork

    ufw-docker--allow instance-name "" ""
}
test-ipv6-allow-internal-succeeds-for-all-published-ports-on-multinetwork-assert() {
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

test-ipv6-allow-internal-succeeds-for-all-published-ports-on-selected-multinetwork() {
    setup-IPv6-ufw-docker--allow--multinetwork

    ufw-docker--allow instance-name "" "" awesomenet
}
test-ipv6-allow-internal-succeeds-for-all-published-ports-on-selected-multinetwork-assert() {
    ufw-docker--add-rule  instance-name  172.19.0.7  5000  tcp  awesomenet
    ufw-docker--add-rule instance-name/v6 fd00:cf::207 5000 tcp awesomenet
    ufw-docker--add-rule  instance-name  172.19.0.7  8080  tcp  awesomenet
    ufw-docker--add-rule instance-name/v6 fd00:cf::207 8080 tcp awesomenet
    ufw-docker--add-rule  instance-name  172.19.0.7  5353  udp  awesomenet
    ufw-docker--add-rule instance-name/v6 fd00:cf::207 5353 udp awesomenet
}


test-add-rule-for-non-existing-rule() {
    @mockfalse ufw-docker--list webapp 5000 tcp ""
    @ignore echo

    load-ufw-docker-function ufw-docker--add-rule
    ufw-docker--add-rule webapp 172.18.0.4 5000 tcp
}
test-add-rule-for-non-existing-rule-assert() {
    ufw route allow proto tcp from any to 172.18.0.4 port 5000 comment "allow webapp 5000/tcp"
}

test-add-rule-for-non-existing-rule-with-network() {
    @mockfalse ufw-docker--list webapp 5000 tcp default
    @ignore echo

    load-ufw-docker-function ufw-docker--add-rule
    ufw-docker--add-rule webapp 172.18.0.4 5000 tcp default
}
test-add-rule-for-non-existing-rule-with-network-assert() {
    ufw route allow proto tcp from any to 172.18.0.4 port 5000 comment "allow webapp 5000/tcp default"
}


test-add-rule-modifies-existing-rule() {
    @mocktrue ufw-docker--list webapp 5000 tcp default
    @mock ufw --dry-run route allow proto tcp from any to 172.18.0.4 port 5000 comment "allow webapp 5000/tcp default" === @echo
    @mockfalse grep "^Skipping"
    @ignore echo

    load-ufw-docker-function ufw-docker--add-rule
    ufw-docker--add-rule webapp 172.18.0.4 5000 tcp default
}
test-add-rule-modifies-existing-rule-assert() {
    ufw-docker--delete webapp 5000 tcp default

    ufw route allow proto tcp from any to 172.18.0.4 port 5000 comment "allow webapp 5000/tcp default"
}


test-ipv6-add-rule-modifies-existing-rule() {
    @mocktrue ufw-docker--list webapp/v6 5000 tcp default
    @mock ufw --dry-run route allow proto tcp from any to fd00:cf::42 port 5000 comment "allow webapp/v6 5000/tcp default" === @echo
    @mockfalse grep "^Skipping"
    @ignore echo

    load-ufw-docker-function ufw-docker--add-rule
    ufw-docker--add-rule webapp/v6 fd00:cf::42 5000 tcp default
}
test-ipv6-add-rule-modifies-existing-rule-assert() {
    ufw-docker--delete webapp/v6 5000 tcp default

    ufw route allow proto tcp from any to fd00:cf::42 port 5000 comment "allow webapp/v6 5000/tcp default"
}


test-add-rule-skips-existing-rule() {
    @mocktrue ufw-docker--list webapp 5000 tcp ""
    @mocktrue ufw --dry-run route allow proto tcp from any to 172.18.0.4 port 5000 comment "allow webapp 5000/tcp"
    @mocktrue grep "^Skipping"
    @ignore echo

    load-ufw-docker-function ufw-docker--add-rule
    ufw-docker--add-rule webapp 172.18.0.4 5000 tcp ""
}
test-add-rule-skips-existing-rule-assert() {
    @do-nothing
}


test-add-rule-modifies-existing-rule-without-port() {
    @mocktrue ufw-docker--list webapp "" tcp ""
    @mock ufw --dry-run route allow proto tcp from any to 172.18.0.4 comment "allow webapp" === @echo
    @mockfalse grep "^Skipping"
    @ignore echo

    load-ufw-docker-function ufw-docker--add-rule

    ufw-docker--add-rule webapp 172.18.0.4 "" tcp ""
}
test-add-rule-modifies-existing-rule-without-port-assert() {
    ufw-docker--delete webapp "" tcp ""

    ufw route allow proto tcp from any to 172.18.0.4 comment "allow webapp"
}


test-instance-name-resolves-from-name() {
    @mock docker inspect --format="{{.Name}}" foo
    @mock sed -e 's,^/,,'
    @mockfalse grep "^$GREP_REGEXP_NAME\$"

    @mock echo -n foo

    load-ufw-docker-function ufw-docker--instance-name
    ufw-docker--instance-name foo
}
test-instance-name-resolves-from-name-assert() {
    docker inspect --format="{{.Name}}" foo
    @dryrun echo -n foo
}


test-instance-name-resolves-from-id() {
    @mock docker inspect --format="{{.Name}}" fooid
    @mock sed -e 's,^/,,'
    @mockfalse grep "^$GREP_REGEXP_NAME\$"
    @mock echo -n fooid

    load-ufw-docker-function ufw-docker--instance-name
    ufw-docker--instance-name fooid
}
test-instance-name-resolves-from-id-assert() {
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

test-status-internal() {
    mock-ufw-status-numbered-foo
    @allow-real grep '# allow [-_.[:alnum:]]\+\(/v6\)\?\( [[:digit:]]\+/\(tcp\|udp\)\( [-_.[:alnum:]]\+\)\?\)\?$'

    load-ufw-docker-function ufw-docker--list
    load-ufw-docker-function ufw-docker--status
    ufw-docker--status
}
test-status-internal-assert() {
    test-list-internal-all-rules-assert
}

test-list-internal-all-rules() {
    mock-ufw-status-numbered-foo
    @allow-real grep '# allow [-_.[:alnum:]]\+\(/v6\)\?\( [[:digit:]]\+/\(tcp\|udp\)\( [-_.[:alnum:]]\+\)\?\)\?$'

    load-ufw-docker-function ufw-docker--list
    ufw-docker--list
}
test-list-internal-all-rules-assert() {
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

test-list-internal-rules-by-name() {
    mock-ufw-status-numbered-foo
    @allow-real grep '# allow foo\(/v6\)\?\( [[:digit:]]\+/\(tcp\|udp\)\( [-_.[:alnum:]]\+\)\?\)\?$'

    load-ufw-docker-function ufw-docker--list
    ufw-docker--list foo
}
test-list-internal-rules-by-name-assert() {
    @stdout "[ 3] 172.17.0.3 80/tcp          ALLOW FWD   Anywhere                   # allow foo 80/tcp bridge"
    @stdout "[ 5] 172.17.0.3 53/udp          ALLOW FWD   Anywhere                   # allow foo 53/udp foo-internal"
    @stdout "[ 6] 172.17.0.3 53/tcp          ALLOW FWD   Anywhere                   # allow foo 53/tcp"
    @stdout "[12] fd00:a:b:deaf::3 80/tcp    ALLOW FWD   Anywhere (v6)              # allow foo/v6 80/tcp bridge"
    @stdout "[14] fd00:a:b:deaf::3 53/udp    ALLOW FWD   Anywhere (v6)              # allow foo/v6 53/udp foo-internal"
    @stdout "[15] fd00:a:b:deaf::3 53/tcp    ALLOW FWD   Anywhere (v6)              # allow foo/v6 53/tcp"
}

test-list-internal-rules-by-name-and-udp-protocol() {
    mock-ufw-status-numbered-foo
    @allow-real grep '# allow foo\(/v6\)\? [[:digit:]]\+/udp\( [-_.[:alnum:]]\+\)\?$'

    load-ufw-docker-function ufw-docker--list
    ufw-docker--list foo "" udp
}
test-list-internal-rules-by-name-and-udp-protocol-assert() {
    @stdout "[ 5] 172.17.0.3 53/udp          ALLOW FWD   Anywhere                   # allow foo 53/udp foo-internal"
    @stdout "[14] fd00:a:b:deaf::3 53/udp    ALLOW FWD   Anywhere (v6)              # allow foo/v6 53/udp foo-internal"
}


test-list-internal-rules-by-name-port-and-bridge-network() {
    mock-ufw-status-numbered-foo
    @allow-real grep '# allow foo\(/v6\)\? 80/tcp bridge$'

    load-ufw-docker-function ufw-docker--list
    ufw-docker--list foo 80 "" bridge
}
test-list-internal-rules-by-name-port-and-bridge-network-assert() {
    @stdout "[ 3] 172.17.0.3 80/tcp          ALLOW FWD   Anywhere                   # allow foo 80/tcp bridge"
    @stdout "[12] fd00:a:b:deaf::3 80/tcp    ALLOW FWD   Anywhere (v6)              # allow foo/v6 80/tcp bridge"
}


test-list-internal-rules-by-name-port-and-udp-protocol() {
    mock-ufw-status-numbered-foo
    @allow-real grep '# allow foo\(/v6\)\? 53/udp\( [-_.[:alnum:]]\+\)\?$'

    load-ufw-docker-function ufw-docker--list
    ufw-docker--list foo 53 udp
}
test-list-internal-rules-by-name-port-and-udp-protocol-assert() {
    @stdout "[ 5] 172.17.0.3 53/udp          ALLOW FWD   Anywhere                   # allow foo 53/udp foo-internal"
    @stdout "[14] fd00:a:b:deaf::3 53/udp    ALLOW FWD   Anywhere (v6)              # allow foo/v6 53/udp foo-internal"
}


test-list-internal-fails-with-incorrect-network() {
    mock-ufw-status-numbered-foo
    @allow-real grep '# allow foo\(/v6\)\? 53/udp incorrect-network$'

    load-ufw-docker-function ufw-docker--list
    ufw-docker--list foo 53 udp incorrect-network
}
test-list-internal-fails-with-incorrect-network-assert() {
    @fail
}


test-list-internal-rules-by-name-and-port() {
    mock-ufw-status-numbered-foo
    @allow-real grep '# allow foo\(/v6\)\? 80/tcp\( [-_.[:alnum:]]\+\)\?$'

    load-ufw-docker-function ufw-docker--list
    ufw-docker--list foo 80
}
test-list-internal-rules-by-name-and-port-assert() {
    @stdout "[ 3] 172.17.0.3 80/tcp          ALLOW FWD   Anywhere                   # allow foo 80/tcp bridge"
    @stdout "[12] fd00:a:b:deaf::3 80/tcp    ALLOW FWD   Anywhere (v6)              # allow foo/v6 80/tcp bridge"
}


test-list-number-internal() {
    @mocktrue ufw-docker--list foo 53 udp

    load-ufw-docker-function ufw-docker--list-number
    ufw-docker--list-number foo 53 udp
}
test-list-number-internal-assert() {
    sed -e 's/^\[[[:blank:]]*\([[:digit:]]\+\)\].*/\1/'
}


test-delete-internal-does-nothing-for-empty-result() {
    @mock ufw-docker--list-number webapp 80 tcp === @stdout ""
    @mockpipe sort -rn

    load-ufw-docker-function ufw-docker--delete
    ufw-docker--delete webapp 80 tcp
}
test-delete-internal-does-nothing-for-empty-result-assert() {
    @do-nothing
}


test-delete-internal-all-rules() {
    @mock ufw-docker--list-number webapp 80 tcp === @stdout 5 8 9
    @mockpipe sort -rn
    @ignore echo

    load-ufw-docker-function ufw-docker--delete
    ufw-docker--delete webapp 80 tcp
}
test-delete-internal-all-rules-assert() {
    ufw delete 5
    ufw delete 8
    ufw delete 9
}

test-check-install-ipv4() {
    @mock mktemp === @stdout /tmp/after_rules_tmp
    @mock sed "/^# BEGIN UFW AND DOCKER/,/^# END UFW AND DOCKER/d" /etc/ufw/after.rules
    @mock tee "/tmp/after_rules_tmp"
    @capture tee -a /tmp/after_rules_tmp
    @allow-real cat

    load-ufw-docker-function ufw-docker--check-install
    ufw-docker--check-install
}
test-check-install-ipv4-assert() {
    rm-on-exit /tmp/after_rules_tmp
    sed "/^# BEGIN UFW AND DOCKER/,/^# END UFW AND DOCKER/d" /etc/ufw/after.rules
    @assert-capture tee -a /tmp/after_rules_tmp <<\EOF
# BEGIN UFW AND DOCKER
*filter
:ufw-user-forward - [0:0]
:ufw-docker-logging-deny - [0:0]
:DOCKER-USER - [0:0]
-A DOCKER-USER -j ufw-user-forward

-A DOCKER-USER -m conntrack --ctstate RELATED,ESTABLISHED -j RETURN
-A DOCKER-USER -m conntrack --ctstate INVALID -j DROP
-A DOCKER-USER -i docker0 -o docker0 -j ACCEPT

-A DOCKER-USER -j RETURN -s 10.0.0.0/8
-A DOCKER-USER -j RETURN -s 172.16.0.0/12
-A DOCKER-USER -j RETURN -s 192.168.0.0/16
-A DOCKER-USER -j ufw-docker-logging-deny -m conntrack --ctstate NEW -d 10.0.0.0/8
-A DOCKER-USER -j ufw-docker-logging-deny -m conntrack --ctstate NEW -d 172.16.0.0/12
-A DOCKER-USER -j ufw-docker-logging-deny -m conntrack --ctstate NEW -d 192.168.0.0/16

-A DOCKER-USER -j RETURN

-A ufw-docker-logging-deny -m limit --limit 3/min --limit-burst 10 -j LOG --log-prefix "[UFW DOCKER BLOCK] "
-A ufw-docker-logging-deny -j DROP

COMMIT
# END UFW AND DOCKER
EOF
    diff -u --color=auto /etc/ufw/after.rules /tmp/after_rules_tmp
}

test-check-install-ipv4-with-subnets() {
    @mock ufw-docker--list-docker-subnets IPv4 192.168.56.128/28 172.16.0.0/12 === @stdout "172.16.0.0/12" "192.168.56.128/28"
    @mock mktemp === @stdout /tmp/after_rules_tmp
    @mock sed "/^# BEGIN UFW AND DOCKER/,/^# END UFW AND DOCKER/d" /etc/ufw/after.rules
    @mock tee "/tmp/after_rules_tmp"
    @capture tee -a /tmp/after_rules_tmp
    @allow-real cat

    load-ufw-docker-function ufw-docker--check-install
    ufw-docker--check-install --docker-subnets 192.168.56.128/28 172.16.0.0/12
}
test-check-install-ipv4-with-subnets-assert() {
    rm-on-exit /tmp/after_rules_tmp
    sed "/^# BEGIN UFW AND DOCKER/,/^# END UFW AND DOCKER/d" /etc/ufw/after.rules
    @assert-capture tee -a /tmp/after_rules_tmp <<\EOF
# BEGIN UFW AND DOCKER
*filter
:ufw-user-forward - [0:0]
:ufw-docker-logging-deny - [0:0]
:DOCKER-USER - [0:0]
-A DOCKER-USER -j ufw-user-forward

-A DOCKER-USER -m conntrack --ctstate RELATED,ESTABLISHED -j RETURN
-A DOCKER-USER -m conntrack --ctstate INVALID -j DROP
-A DOCKER-USER -i docker0 -o docker0 -j ACCEPT

-A DOCKER-USER -j RETURN -s 172.16.0.0/12
-A DOCKER-USER -j RETURN -s 192.168.56.128/28
-A DOCKER-USER -j ufw-docker-logging-deny -m conntrack --ctstate NEW -d 172.16.0.0/12
-A DOCKER-USER -j ufw-docker-logging-deny -m conntrack --ctstate NEW -d 192.168.56.128/28

-A DOCKER-USER -j RETURN

-A ufw-docker-logging-deny -m limit --limit 3/min --limit-burst 10 -j LOG --log-prefix "[UFW DOCKER BLOCK] "
-A ufw-docker-logging-deny -j DROP

COMMIT
# END UFW AND DOCKER
EOF
    diff -u --color=auto /etc/ufw/after.rules /tmp/after_rules_tmp
}

test-check-install-ipv6-with-subnets() {
    @mock ufw-docker--list-docker-subnets IPv6 fd00:cf::/64 fd00::/8 === @stdout "fd00::/8" "fd00:cf::/64"
    @mock mktemp === @stdout /tmp/after6_rules_tmp
    @mock sed "/^# BEGIN UFW AND DOCKER/,/^# END UFW AND DOCKER/d" /etc/ufw/after6.rules
    @mock tee "/tmp/after6_rules_tmp"
    @capture tee -a /tmp/after6_rules_tmp
    @allow-real cat

    load-ufw-docker-function ufw-docker--check-install_ipv6
    ufw-docker--check-install_ipv6 --docker-subnets fd00:cf::/64 fd00::/8
}
test-check-install-ipv6-with-subnets-assert() {
    rm-on-exit /tmp/after6_rules_tmp
    sed "/^# BEGIN UFW AND DOCKER/,/^# END UFW AND DOCKER/d" /etc/ufw/after6.rules
    @assert-capture tee -a /tmp/after6_rules_tmp <<\EOF
# BEGIN UFW AND DOCKER
*filter
:ufw6-user-forward - [0:0]
:ufw6-docker-logging-deny - [0:0]
:DOCKER-USER - [0:0]
-A DOCKER-USER -j ufw6-user-forward

-A DOCKER-USER -m conntrack --ctstate RELATED,ESTABLISHED -j RETURN
-A DOCKER-USER -m conntrack --ctstate INVALID -j DROP
-A DOCKER-USER -i docker0 -o docker0 -j ACCEPT

-A DOCKER-USER -j RETURN -s fd00::/8
-A DOCKER-USER -j RETURN -s fd00:cf::/64
-A DOCKER-USER -j ufw6-docker-logging-deny -m conntrack --ctstate NEW -d fd00::/8
-A DOCKER-USER -j ufw6-docker-logging-deny -m conntrack --ctstate NEW -d fd00:cf::/64

-A DOCKER-USER -j RETURN

-A ufw6-docker-logging-deny -m limit --limit 3/min --limit-burst 10 -j LOG --log-prefix "[UFW DOCKER BLOCK] "
-A ufw6-docker-logging-deny -j DROP

COMMIT
# END UFW AND DOCKER
EOF
    diff -u --color=auto /etc/ufw/after6.rules /tmp/after6_rules_tmp
}

test-man-command() {
  @capture man -l -

	ufw-docker man
}
test-man-command-assert() {
	@assert-capture man -l - <<< "MAN PAGE FOR UFW-DOCKER"
}

test-install-command-with-system() {
	@mock ufw-docker--check-install === @true
	@mock ufw-docker--check-install_ipv6 === @true
  @allow-real dirname /usr/local/bin/ufw-docker
  @allow-real dirname /usr/local/man/man8/ufw-docker.8
  @capture tee /usr/local/man/man8/ufw-docker.8

	load-ufw-docker-function ufw-docker--install

	ufw-docker--install --system
}
test-install-command-with-system-assert() {
  mkdir -p /usr/local/bin
  cp -- test/ufw-docker.test.sh /usr/local/bin/ufw-docker

  mkdir -p /usr/local/man/man8
  @assert-capture tee /usr/local/man/man8/ufw-docker.8 <<< "MAN PAGE FOR UFW-DOCKER"

	mandb -q
}

test-check-command-with-system() {
	@mockfalse command -v ip6tables
  @mock err "Installing man page to '/usr/local/man/man8/ufw-docker.8'"

	load-ufw-docker-function ufw-docker--check

	ufw-docker--check --system
}
test-check-command-with-system-assert() {
	iptables -n -L DOCKER-USER
	ufw-docker--check-install
  err "Installing man page to '/usr/local/man/man8/ufw-docker.8'"
}

setup-ufw-docker--uninstall() {
    @mock date '+%Y-%m-%d-%H%M' === @stdout 2009-02-14-0731

    @mocktrue grep -F 'UFW DOCKER' /etc/ufw/after.rules
    @mocktrue grep -F 'UFW DOCKER' /etc/ufw/after6.rules

    @mocktrue docker service inspect ufw-docker-agent

    @mocktrue [ -f /usr/local/bin/ufw-docker ]
    @mocktrue [ -f /usr/local/man/man8/ufw-docker.8 ]

    @mocktrue type systemctl
}
test-ufw-docker--uninstall() {
    setup-ufw-docker--uninstall

    load-ufw-docker-function ufw-docker--uninstall

    ufw-docker--uninstall
}
test-ufw-docker--uninstall-assert() {
    cp -v /etc/ufw/after.rules /etc/ufw/after.rules~2009-02-14-0731
    sed -i -e '/^# BEGIN UFW AND DOCKER/,/^# END UFW AND DOCKER/d' /etc/ufw/after.rules
    diff /etc/ufw/after.rules~2009-02-14-0731 /etc/ufw/after.rules

    cp -v /etc/ufw/after6.rules /etc/ufw/after6.rules~2009-02-14-0731
    sed -i -e '/^# BEGIN UFW AND DOCKER/,/^# END UFW AND DOCKER/d' /etc/ufw/after6.rules
    diff /etc/ufw/after6.rules~2009-02-14-0731 /etc/ufw/after6.rules

    docker service rm ufw-docker-agent

    rm -v /usr/local/bin/ufw-docker
    rm -v /usr/local/man/man8/ufw-docker.8
}

test-ufw-docker--uninstall-missing-rules() {
    setup-ufw-docker--uninstall
    @mockfalse grep -F 'UFW DOCKER' /etc/ufw/after.rules
    @mockfalse grep -F 'UFW DOCKER' /etc/ufw/after6.rules

    load-ufw-docker-function ufw-docker--uninstall

    ufw-docker--uninstall
}
test-ufw-docker--uninstall-missing-rules-assert() {
    # Expect no cp or sed calls for after.rules/after6.rules
    docker service rm ufw-docker-agent

    rm -v /usr/local/bin/ufw-docker
    rm -v /usr/local/man/man8/ufw-docker.8
}

test-ufw-docker--uninstall-no-service() {
    setup-ufw-docker--uninstall
    @mockfalse docker service inspect ufw-docker-agent # Service not found

    load-ufw-docker-function ufw-docker--uninstall

    ufw-docker--uninstall
}
test-ufw-docker--uninstall-no-service-assert() {
    cp -v /etc/ufw/after.rules /etc/ufw/after.rules~2009-02-14-0731
    sed -i -e '/^# BEGIN UFW AND DOCKER/,/^# END UFW AND DOCKER/d' /etc/ufw/after.rules
    diff /etc/ufw/after.rules~2009-02-14-0731 /etc/ufw/after.rules

    cp -v /etc/ufw/after6.rules /etc/ufw/after6.rules~2009-02-14-0731
    sed -i -e '/^# BEGIN UFW AND DOCKER/,/^# END UFW AND DOCKER/d' /etc/ufw/after6.rules
    diff /etc/ufw/after6.rules~2009-02-14-0731 /etc/ufw/after6.rules

    # Expect no docker service rm call
    rm -v /usr/local/bin/ufw-docker
    rm -v /usr/local/man/man8/ufw-docker.8
}

test-ufw-docker--uninstall-missing-files() {
    setup-ufw-docker--uninstall
    @mockfalse [ -f /usr/local/bin/ufw-docker ]   # Binary missing
    @mockfalse [ -f /usr/local/man/man8/ufw-docker.8 ] # Man page missing

    load-ufw-docker-function ufw-docker--uninstall

    ufw-docker--uninstall
}
test-ufw-docker--uninstall-missing-files-assert() {
    cp -v /etc/ufw/after.rules /etc/ufw/after.rules~2009-02-14-0731
    sed -i -e '/^# BEGIN UFW AND DOCKER/,/^# END UFW AND DOCKER/d' /etc/ufw/after.rules
    diff /etc/ufw/after.rules~2009-02-14-0731 /etc/ufw/after.rules

    cp -v /etc/ufw/after6.rules /etc/ufw/after6.rules~2009-02-14-0731
    sed -i -e '/^# BEGIN UFW AND DOCKER/,/^# END UFW AND DOCKER/d' /etc/ufw/after6.rules
    diff /etc/ufw/after6.rules~2009-02-14-0731 /etc/ufw/after6.rules

    docker service rm ufw-docker-agent

    # Expect no rm calls for missing files
}

test-list-docker-subnets-ipv4-auto() {
    @mock docker network ls --format '{{.ID}}' === @stdout "net1" "net2"
    @mock docker network inspect "net1" --format '{{range .IPAM.Config}}{{.Subnet}}{{"\n"}}{{end}}' === @stdout "172.18.0.0/16"
    @mock docker network inspect "net2" --format '{{range .IPAM.Config}}{{.Subnet}}{{"\n"}}{{end}}' === @stdout "172.19.0.0/16"

    load-ufw-docker-function ufw-docker--list-docker-subnets
    ufw-docker--list-docker-subnets IPv4
}
test-list-docker-subnets-ipv4-auto-assert() {
    @stdout "172.18.0.0/16"
    @stdout "172.19.0.0/16"
}

test-list-docker-subnets-ipv6-auto() {
    @mock docker network ls --format '{{.ID}}' === @stdout "net1" "net2"
    @mock docker network inspect "net1" --format '{{range .IPAM.Config}}{{.Subnet}}{{"\n"}}{{end}}' === @stdout "fd00:1::/64"
    @mock docker network inspect "net2" --format '{{range .IPAM.Config}}{{.Subnet}}{{"\n"}}{{end}}' === @stdout "fd00:2::/64"

    load-ufw-docker-function ufw-docker--list-docker-subnets
    ufw-docker--list-docker-subnets IPv6
}
test-list-docker-subnets-ipv6-auto-assert() {
    @stdout "fd00:1::/64"
    @stdout "fd00:2::/64"
}

test-list-docker-subnets-ipv4-manual() {
    load-ufw-docker-function ufw-docker--list-docker-subnets
    ufw-docker--list-docker-subnets IPv4 10.0.0.0/8 fd00::/8 192.168.0.0/16
}
test-list-docker-subnets-ipv4-manual-assert() {
    @stdout "10.0.0.0/8"
    @stdout "192.168.0.0/16"
}

test-list-docker-subnets-ipv6-manual() {
    load-ufw-docker-function ufw-docker--list-docker-subnets
    ufw-docker--list-docker-subnets IPv6 10.0.0.0/8 fd00::/8 2001:db8::/32
}
test-list-docker-subnets-ipv6-manual-assert() {
    @stdout "2001:db8::/32"
    @stdout "fd00::/8"
}

test-reload-subcommand() {
    ufw-docker reload
}
test-reload-subcommand-assert() {
    ufw-docker--reload
}

mock-reload-rules() {
    @allow-real sed -n 's/.*# allow //p'
    @mock ufw-docker--list === @stdout \
        "[ 3] 172.18.0.2 29090/tcp       ALLOW FWD   Anywhere                   # allow yykjc6r8plexe1oua1iwc1gm8 29090/tcp" \
        "[ 4] 172.18.0.2 40080/tcp       ALLOW FWD   Anywhere                   # allow i9he13jtd78butwzldzbdxz6f 40080/tcp" \
        "[ 5] 172.18.0.2 48080/tcp       ALLOW FWD   Anywhere                   # allow i9he13jtd78butwzldzbdxz6f 48080/tcp" \
        "[ 6] 172.18.0.2 8080/tcp        ALLOW FWD   Anywhere                   # allow b3l5tr2ki1weur4k2pon8qzhv 8080/tcp" \
        "[ 7] 172.18.0.2 9090/tcp        ALLOW FWD   Anywhere                   # allow 328njm00scpkcwig1nym9ktrt 9090/tcp" \
        "[ 8] 172.17.0.6 80/tcp          ALLOW FWD   Anywhere                   # allow public_webapp 80/tcp bridge" \
        "[ 9] 172.17.0.5 30000/udp       ALLOW FWD   Anywhere                   # allow udp_echo_test 30000/udp bridge" \
        "[10] 172.20.0.2 80/tcp          ALLOW FWD   Anywhere                   # allow public_multinet_app 80/tcp bar_external_network" \
        "[11] 172.19.0.2 80/tcp          ALLOW FWD   Anywhere                   # allow internal_multinet_app 80/tcp foo_internal_network"

    @mock docker ps --filter "name=${ufw_docker_agent}" -q === @stdout "1234567890ab"
}
test-reload-rules-without-agent() {
    mock-reload-rules
    @mock docker ps --filter "name=${ufw_docker_agent}" -q === @stdout ""

    load-ufw-docker-function ufw-docker--reload
    ufw-docker--reload
}
test-reload-rules-without-agent-assert() {
    ufw-docker--allow yykjc6r8plexe1oua1iwc1gm8 29090 tcp ""
    ufw-docker--allow i9he13jtd78butwzldzbdxz6f 40080 tcp ""
    ufw-docker--allow i9he13jtd78butwzldzbdxz6f 48080 tcp ""
    ufw-docker--allow b3l5tr2ki1weur4k2pon8qzhv 8080 tcp ""
    ufw-docker--allow 328njm00scpkcwig1nym9ktrt 9090 tcp ""
    ufw-docker--allow public_webapp 80 tcp bridge
    ufw-docker--allow udp_echo_test 30000 udp bridge
    ufw-docker--allow public_multinet_app 80 tcp bar_external_network
    ufw-docker--allow internal_multinet_app 80 tcp foo_internal_network
}

test-reload-rules-but-failed-to-recreate-agent() {
    mock-reload-rules
    @mock docker ps --filter "name=${ufw_docker_agent}" -q === @stdout "1234567890ab"
    @mockfalse docker rm -f "1234567890ab"

    load-ufw-docker-function ufw-docker--reload
    ufw-docker--reload
}
test-reload-rules-but-failed-to-recreate-agent-assert() {
    test-reload-rules-without-agent-assert
    for ((i=0; i<10; i++)); do sleep 3; done
    @fail
}

test-reload-rules() {
    mock-reload-rules

    load-ufw-docker-function ufw-docker--reload
    ufw-docker--reload
}
test-reload-rules-assert() {
    test-reload-rules-without-agent-assert

    docker rm -f "1234567890ab"
}

test-reload-unexisting-rules() {
    mock-reload-rules
    @mockfalse ufw-docker--allow i9he13jtd78butwzldzbdxz6f 40080 tcp ""
    @mockfalse ufw-docker--allow i9he13jtd78butwzldzbdxz6f 48080 tcp ""
    @mockfalse ufw-docker--allow b3l5tr2ki1weur4k2pon8qzhv 8080 tcp ""

    load-ufw-docker-function ufw-docker--reload
    ufw-docker--reload
}
test-reload-unexisting-rules-assert() {
    ufw-docker--allow yykjc6r8plexe1oua1iwc1gm8 29090 tcp ""

    ufw-docker--delete i9he13jtd78butwzldzbdxz6f 40080 tcp ""
    ufw-docker--delete i9he13jtd78butwzldzbdxz6f 48080 tcp ""
    ufw-docker--delete b3l5tr2ki1weur4k2pon8qzhv 8080 tcp ""

    ufw-docker--allow 328njm00scpkcwig1nym9ktrt 9090 tcp ""
    ufw-docker--allow public_webapp 80 tcp bridge
    ufw-docker--allow udp_echo_test 30000 udp bridge
    ufw-docker--allow public_multinet_app 80 tcp bar_external_network
    ufw-docker--allow internal_multinet_app 80 tcp foo_internal_network

    docker rm -f "1234567890ab"
}