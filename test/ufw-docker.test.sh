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
    ufw-docker--list httpd-container-name "" "" tcp ""
}


test-allow-command-for-instance() {
    @mock ufw-docker--instance-name httpd === @stdout httpd-container-name
    ufw-docker allow httpd
}
test-allow-command-for-instance-assert() {
    ufw-docker--allow httpd-container-name "" "" tcp ""
}


test-allow-command-for-instance-with-port() {
    @mock ufw-docker--instance-name httpd === @stdout httpd-container-name
    ufw-docker allow httpd any 80
}
test-allow-command-for-instance-with-port-assert() {
    ufw-docker--allow httpd-container-name any 80 tcp ""
}


test-allow-command-for-instance-with-port-and-tcp-protocol() {
    @mock ufw-docker--instance-name httpd === @stdout httpd-container-name
    ufw-docker allow httpd any 80/tcp
}
test-allow-command-for-instance-with-port-and-tcp-protocol-assert() {
    ufw-docker--allow httpd-container-name any 80 tcp ""
}


test-allow-command-for-instance-with-port-and-udp-protocol() {
    @mock ufw-docker--instance-name httpd === @stdout httpd-container-name
    ufw-docker allow httpd any 80/udp
}
test-allow-command-for-instance-with-port-and-udp-protocol-assert() {
    ufw-docker--allow httpd-container-name any 80 udp ""
}


test-allow-command-for-instance-with-source-ip() {
    @mock ufw-docker--instance-name httpd === @stdout httpd-container-name
    ufw-docker allow httpd 192.168.1.10 80/tcp
}
test-allow-command-for-instance-with-source-ip-assert() {
    ufw-docker--allow httpd-container-name 192.168.1.10 80 tcp ""
}


test-allow-command-for-instance-with-source-subnet() {
    @mock ufw-docker--instance-name httpd === @stdout httpd-container-name
    ufw-docker allow httpd 192.168.1.0/24 80/tcp
}
test-allow-command-for-instance-with-source-subnet-assert() {
    ufw-docker--allow httpd-container-name 192.168.1.0/24 80 tcp ""
}


test-allow-command-for-instance-with-source-any() {
    @mock ufw-docker--instance-name httpd === @stdout httpd-container-name
    ufw-docker allow httpd any 80/tcp
}
test-allow-command-for-instance-with-source-any-assert() {
    ufw-docker--allow httpd-container-name any 80 tcp ""
}


test-allow-command-for-instance-with-source-and-network() {
    @mock ufw-docker--instance-name httpd === @stdout httpd-container-name
    ufw-docker allow httpd 192.168.1.10 80/tcp default
}
test-allow-command-for-instance-with-source-and-network-assert() {
    ufw-docker--allow httpd-container-name 192.168.1.10 80 tcp default
}


test-ASSERT-FAIL-allow-httpd-INVALID-port() {
    @mock ufw-docker--instance-name httpd === @stdout httpd-container-name
    @mock die 'invalid port syntax: "invalid".' === exit 1

    ufw-docker allow httpd any invalid
}


test-ASSERT-FAIL-allow-httpd-INVALID-source() {
    @mock ufw-docker--instance-name httpd === @stdout httpd-container-name
    @mock die 'invalid source syntax: "invalid-source".' === exit 1

    ufw-docker allow httpd invalid-source
}


test-delete-allow-command-for-instance() {
    @mock ufw-docker--instance-name httpd === @stdout httpd-container-name
    ufw-docker delete allow httpd
}
test-delete-allow-command-for-instance-assert() {
    ufw-docker--delete httpd-container-name "" "" tcp ""
}


test-delete-allow-command-for-instance-with-source() {
    @mock ufw-docker--instance-name httpd === @stdout httpd-container-name
    ufw-docker delete allow httpd 192.168.1.10 80/tcp
}
test-delete-allow-command-for-instance-with-source-assert() {
    ufw-docker--delete httpd-container-name 192.168.1.10 80 tcp ""
}


test-delete-allow-command-for-instance-with-source-and-network() {
    @mock ufw-docker--instance-name httpd === @stdout httpd-container-name
    ufw-docker delete allow httpd 192.168.1.10 80/tcp default
}
test-delete-allow-command-for-instance-with-source-and-network-assert() {
    ufw-docker--delete httpd-container-name 192.168.1.10 80 tcp default
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


test-allow-internal-fails-for-non-existent-instance() {
    setup-ufw-docker--allow

    @mockfalse docker inspect invalid-instance
    @mockfalse die "Docker instance \"invalid-instance\" doesn't exist."

    ufw-docker--allow invalid-instance any 80 tcp
}
test-allow-internal-fails-for-non-existent-instance-assert() {
    @do-nothing
    @fail
}


test-allow-internal-fails-when-port-does-not-match() {
    setup-ufw-docker--allow

    ufw-docker--allow instance-name any 80 tcp
}
test-allow-internal-fails-when-port-does-not-match-assert() {
    @do-nothing
    @fail
}


test-allow-internal-fails-when-protocol-does-not-match() {
    setup-ufw-docker--allow

    ufw-docker--allow instance-name any 5353 tcp
}
test-allow-internal-fails-when-protocol-does-not-match-assert() {
    @do-nothing
    @fail
}


test-allow-internal-succeeds-when-port-matches() {
    setup-ufw-docker--allow

    ufw-docker--allow instance-name any 5000 tcp
}
test-allow-internal-succeeds-when-port-matches-assert() {
    ufw-docker--add-rule instance-name 172.18.0.3 any 5000 tcp default
}


test-allow-internal-succeeds-for-all-published-ports() {
    setup-ufw-docker--allow

    ufw-docker--allow instance-name any "" ""
}
test-allow-internal-succeeds-for-all-published-ports-assert() {
    ufw-docker--add-rule  instance-name  172.18.0.3  any  5000  tcp  default
    ufw-docker--add-rule  instance-name  172.18.0.3  any  8080  tcp  default
    ufw-docker--add-rule  instance-name  172.18.0.3  any  5353  udp  default
}


test-allow-internal-succeeds-for-all-published-tcp-ports() {
    setup-ufw-docker--allow

    ufw-docker--allow instance-name any "" tcp
}
test-allow-internal-succeeds-for-all-published-tcp-ports-assert() {
    ufw-docker--add-rule  instance-name  172.18.0.3  any  5000  tcp  default
    ufw-docker--add-rule  instance-name  172.18.0.3  any  8080  tcp  default
    ufw-docker--add-rule  instance-name  172.18.0.3  any  5353  udp  default # FIXME
}


test-allow-internal-succeeds-for-all-published-ports-on-multinetwork() {
    setup-ufw-docker--allow--multinetwork

    ufw-docker--allow instance-name any "" ""
}
test-allow-internal-succeeds-for-all-published-ports-on-multinetwork-assert() {
    ufw-docker--add-rule  instance-name  172.18.0.3  any  5000  tcp  default
    ufw-docker--add-rule  instance-name  172.19.0.7  any  5000  tcp  awesomenet
    ufw-docker--add-rule  instance-name  172.18.0.3  any  8080  tcp  default
    ufw-docker--add-rule  instance-name  172.19.0.7  any  8080  tcp  awesomenet
    ufw-docker--add-rule  instance-name  172.18.0.3  any  5353  udp  default
    ufw-docker--add-rule  instance-name  172.19.0.7  any  5353  udp  awesomenet
}

test-allow-internal-succeeds-for-all-published-ports-on-selected-multinetwork() {
    setup-ufw-docker--allow--multinetwork

    ufw-docker--allow instance-name any "" "" awesomenet
}
test-allow-internal-succeeds-for-all-published-ports-on-selected-multinetwork-assert() {
    ufw-docker--add-rule  instance-name  172.19.0.7  any  5000  tcp  awesomenet
    ufw-docker--add-rule  instance-name  172.19.0.7  any  8080  tcp  awesomenet
    ufw-docker--add-rule  instance-name  172.19.0.7  any  5353  udp  awesomenet
}


test-ipv6-allow-internal-succeeds-when-port-matches() {
    setup-IPv6-ufw-docker--allow

    ufw-docker--allow instance-name any 5000 tcp
}
test-ipv6-allow-internal-succeeds-when-port-matches-assert() {
    ufw-docker--add-rule  instance-name     172.18.0.3   any  5000  tcp  default
    ufw-docker--add-rule  instance-name/v6  fd00:cf::42  any  5000  tcp  default
}


test-ipv6-allow-internal-succeeds-for-all-published-ports() {
    setup-IPv6-ufw-docker--allow

    ufw-docker--allow instance-name any "" ""
}
test-ipv6-allow-internal-succeeds-for-all-published-ports-assert() {
    ufw-docker--add-rule  instance-name     172.18.0.3   any  5000  tcp  default
    ufw-docker--add-rule  instance-name/v6  fd00:cf::42  any  5000  tcp  default
    ufw-docker--add-rule  instance-name     172.18.0.3   any  8080  tcp  default
    ufw-docker--add-rule  instance-name/v6  fd00:cf::42  any  8080  tcp  default
    ufw-docker--add-rule  instance-name     172.18.0.3   any  5353  udp  default
    ufw-docker--add-rule  instance-name/v6  fd00:cf::42  any  5353  udp  default
}


test-ipv6-allow-internal-succeeds-for-all-published-tcp-ports() {
    setup-IPv6-ufw-docker--allow

    ufw-docker--allow instance-name any "" tcp
}
test-ipv6-allow-internal-succeeds-for-all-published-tcp-ports-assert() {
    ufw-docker--add-rule  instance-name     172.18.0.3   any  5000  tcp  default
    ufw-docker--add-rule  instance-name/v6  fd00:cf::42  any  5000  tcp  default
    ufw-docker--add-rule  instance-name     172.18.0.3   any  8080  tcp  default
    ufw-docker--add-rule  instance-name/v6  fd00:cf::42  any  8080  tcp  default
    ufw-docker--add-rule  instance-name     172.18.0.3   any  5353  udp  default # FIXME
    ufw-docker--add-rule  instance-name/v6  fd00:cf::42  any  5353  udp  default # FIXME
}


test-ipv6-allow-internal-succeeds-for-all-published-ports-on-multinetwork() {
    setup-IPv6-ufw-docker--allow--multinetwork

    ufw-docker--allow instance-name any "" ""
}
test-ipv6-allow-internal-succeeds-for-all-published-ports-on-multinetwork-assert() {
    ufw-docker--add-rule  instance-name     172.18.0.3    any  5000  tcp  default
    ufw-docker--add-rule  instance-name/v6  fd00:cf::42   any  5000  tcp  default
    ufw-docker--add-rule  instance-name     172.19.0.7    any  5000  tcp  awesomenet
    ufw-docker--add-rule  instance-name/v6  fd00:cf::207  any  5000  tcp  awesomenet
    ufw-docker--add-rule  instance-name     172.18.0.3    any  8080  tcp  default
    ufw-docker--add-rule  instance-name/v6  fd00:cf::42   any  8080  tcp  default
    ufw-docker--add-rule  instance-name     172.19.0.7    any  8080  tcp  awesomenet
    ufw-docker--add-rule  instance-name/v6  fd00:cf::207  any  8080  tcp  awesomenet
    ufw-docker--add-rule  instance-name     172.18.0.3    any  5353  udp  default
    ufw-docker--add-rule  instance-name/v6  fd00:cf::42   any  5353  udp  default
    ufw-docker--add-rule  instance-name     172.19.0.7    any  5353  udp  awesomenet
    ufw-docker--add-rule  instance-name/v6  fd00:cf::207  any  5353  udp  awesomenet
}

test-ipv6-allow-internal-succeeds-for-all-published-ports-on-selected-multinetwork() {
    setup-IPv6-ufw-docker--allow--multinetwork

    ufw-docker--allow instance-name any "" "" awesomenet
}
test-ipv6-allow-internal-succeeds-for-all-published-ports-on-selected-multinetwork-assert() {
    ufw-docker--add-rule  instance-name     172.19.0.7    any  5000  tcp  awesomenet
    ufw-docker--add-rule  instance-name/v6  fd00:cf::207  any  5000  tcp  awesomenet
    ufw-docker--add-rule  instance-name     172.19.0.7    any  8080  tcp  awesomenet
    ufw-docker--add-rule  instance-name/v6  fd00:cf::207  any  8080  tcp  awesomenet
    ufw-docker--add-rule  instance-name     172.19.0.7    any  5353  udp  awesomenet
    ufw-docker--add-rule  instance-name/v6  fd00:cf::207  any  5353  udp  awesomenet
}


test-add-rule-for-non-existing-rule() {
    @mockfalse ufw-docker--list webapp any 5000 tcp ""
    @ignore echo

    load-ufw-docker-function ufw-docker--add-rule
    ufw-docker--add-rule webapp 172.18.0.4 any 5000 tcp
}
test-add-rule-for-non-existing-rule-assert() {
    ufw route allow proto tcp from any to 172.18.0.4 port 5000 comment "allow webapp any 5000/tcp"
}

test-add-rule-for-non-existing-rule-with-network() {
    @mockfalse ufw-docker--list webapp any 5000 tcp default
    @ignore echo

    load-ufw-docker-function ufw-docker--add-rule
    ufw-docker--add-rule webapp 172.18.0.4 any 5000 tcp default
}
test-add-rule-for-non-existing-rule-with-network-assert() {
    ufw route allow proto tcp from any to 172.18.0.4 port 5000 comment "allow webapp any 5000/tcp default"
}


test-add-rule-modifies-existing-rule() {
    @mocktrue ufw-docker--list webapp any 5000 tcp default
    @mock ufw --dry-run route allow proto tcp from any to 172.18.0.4 port 5000 comment "allow webapp any 5000/tcp default" === @echo
    @mockfalse grep "^Skipping"
    @ignore echo

    load-ufw-docker-function ufw-docker--add-rule
    ufw-docker--add-rule webapp 172.18.0.4 any 5000 tcp default
}
test-add-rule-modifies-existing-rule-assert() {
    ufw-docker--delete webapp any 5000 tcp default

    ufw route allow proto tcp from any to 172.18.0.4 port 5000 comment "allow webapp any 5000/tcp default"
}


test-ipv6-add-rule-modifies-existing-rule() {
    @mocktrue ufw-docker--list webapp/v6 any 5000 tcp default
    @mock ufw --dry-run route allow proto tcp from any to fd00:cf::42 port 5000 comment "allow webapp/v6 any 5000/tcp default" === @echo
    @mockfalse grep "^Skipping"
    @ignore echo

    load-ufw-docker-function ufw-docker--add-rule
    ufw-docker--add-rule webapp/v6 fd00:cf::42 any 5000 tcp default
}
test-ipv6-add-rule-modifies-existing-rule-assert() {
    ufw-docker--delete webapp/v6 any 5000 tcp default

    ufw route allow proto tcp from any to fd00:cf::42 port 5000 comment "allow webapp/v6 any 5000/tcp default"
}


test-add-rule-skips-existing-rule() {
    @mocktrue ufw-docker--list webapp any 5000 tcp ""
    @mocktrue ufw --dry-run route allow proto tcp from any to 172.18.0.4 port 5000 comment "allow webapp any 5000/tcp"
    @mocktrue grep "^Skipping"
    @ignore echo

    load-ufw-docker-function ufw-docker--add-rule
    ufw-docker--add-rule webapp 172.18.0.4 any 5000 tcp ""
}
test-add-rule-skips-existing-rule-assert() {
    @do-nothing
}


test-add-rule-modifies-existing-rule-without-port() {
    @mocktrue ufw-docker--list webapp any "" tcp ""
    @mock ufw --dry-run route allow proto tcp from any to 172.18.0.4 comment "allow webapp any" === @echo
    @mockfalse grep "^Skipping"
    @ignore echo

    load-ufw-docker-function ufw-docker--add-rule

    ufw-docker--add-rule webapp 172.18.0.4 any "" tcp ""
}
test-add-rule-modifies-existing-rule-without-port-assert() {
    ufw-docker--delete webapp any "" tcp ""

    ufw route allow proto tcp from any to 172.18.0.4 comment "allow webapp any"
}


test-add-rule-for-source-ip() {
    @mockfalse ufw-docker--list webapp 192.168.1.10 5000 tcp ""
    @ignore echo

    load-ufw-docker-function ufw-docker--add-rule
    ufw-docker--add-rule webapp 172.18.0.4 192.168.1.10 5000 tcp
}
test-add-rule-for-source-ip-assert() {
    ufw route allow proto tcp from 192.168.1.10 to 172.18.0.4 port 5000 comment "allow webapp 192.168.1.10 5000/tcp"
}


test-add-rule-for-source-subnet() {
    @mockfalse ufw-docker--list webapp 192.168.1.0/24 5000 tcp ""
    @ignore echo

    load-ufw-docker-function ufw-docker--add-rule
    ufw-docker--add-rule webapp 172.18.0.4 192.168.1.0/24 5000 tcp
}
test-add-rule-for-source-subnet-assert() {
    ufw route allow proto tcp from 192.168.1.0/24 to 172.18.0.4 port 5000 comment "allow webapp 192.168.1.0/24 5000/tcp"
}


test-ipv6-add-rule-for-source-ip() {
    @mockfalse ufw-docker--list webapp fd00:cf::42 5000 tcp ""
    @ignore echo

    load-ufw-docker-function ufw-docker--add-rule
    ufw-docker--add-rule webapp 172.18.0.4 fd00:cf::42 5000 tcp
}
test-ipv6-add-rule-for-source-ip-assert() {
    ufw route allow proto tcp from fd00:cf::42 to 172.18.0.4 port 5000 comment "allow webapp fd00:cf::42 5000/tcp"
}


test-ipv6-add-rule-for-source-subnet() {
    @mockfalse ufw-docker--list webapp fd00:cf::/8 5000 tcp ""
    @ignore echo

    load-ufw-docker-function ufw-docker--add-rule
    ufw-docker--add-rule webapp 172.18.0.4 fd00:cf::/8 5000 tcp
}
test-ipv6-add-rule-for-source-subnet-assert() {
    ufw route allow proto tcp from fd00:cf::/8 to 172.18.0.4 port 5000 comment "allow webapp fd00:cf::/8 5000/tcp"
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
[ 3] 172.17.0.3 80/tcp          ALLOW FWD   Anywhere                   # allow foo any 80/tcp bridge
[ 4] 172.20.0.3 80/tcp          ALLOW FWD   Anywhere                   # allow bar any 80/tcp bar-external
[ 5] 172.17.0.3 53/udp          ALLOW FWD   Anywhere                   # allow foo any 53/udp foo-internal
[ 6] 172.17.0.3 53/tcp          ALLOW FWD   Anywhere                   # allow foo any 53/tcp
[ 7] 172.18.0.2 29090/tcp       ALLOW FWD   Anywhere                   # allow id111111 any 29090/tcp
[ 8] 172.18.0.2 48080/tcp       ALLOW FWD   Anywhere                   # allow id222222 any 48080/tcp
[ 9] 172.18.0.2 40080/tcp       ALLOW FWD   Anywhere                   # allow id333333 any 40080/tcp
[10] 172.18.0.4 8080/tcp        ALLOW FWD   192.168.1.10               # allow baz 192.168.1.10 8080/tcp
[11] 172.18.0.4 8082/udp        ALLOW FWD   192.168.1.10               # allow baz 192.168.1.10 8082/udp
[12] 172.18.0.4 8080/tcp        ALLOW FWD   192.168.2.10/24            # allow baz 192.168.2.10/24 8080/tcp
[13] 172.18.0.4 8081/tcp        ALLOW FWD   192.168.2.10/24            # allow baz 192.168.2.10/24 8081/tcp bridge
[14] OpenSSH (v6)               ALLOW IN    Anywhere (v6)
[15] Anywhere (v6)              ALLOW IN    fd00:a:b:0:cafe::/80
[16] fd00:a:b:deaf::3 80/tcp    ALLOW FWD   Anywhere (v6)              # allow foo/v6 any 80/tcp bridge
[17] fd05:8f23:c937:2::3 80/tcp ALLOW FWD   Anywhere (v6)              # allow bar/v6 any 80/tcp bar-external
[18] fd00:a:b:deaf::3 53/udp    ALLOW FWD   Anywhere (v6)              # allow foo/v6 any 53/udp foo-internal
[19] fd00:a:b:deaf::3 53/tcp    ALLOW FWD   Anywhere (v6)              # allow foo/v6 any 53/tcp
[20] fd00:a:b:deaf::4 8080/tcp  ALLOW FWD   fd00:a:b:0:cafe::1         # allow baz/v6 fd00:a:b:0:cafe::1 8080/tcp
[21] fd00:a:b:deaf::4 8080/tcp  ALLOW FWD   fd00:a:b:0:cafe::/80       # allow baz/v6 fd00:a:b:0:cafe::/80 8080/tcp
[22] fd00:a:b:deaf::4 8081/tcp  ALLOW FWD   fd00:a:b:0:cafe::/80       # allow baz/v6 fd00:a:b:0:cafe::/80 8081/tcp bridge
"

}

test-status-internal() {
    mock-ufw-status-numbered-foo
    @allow-real grep '# allow [-_.[:alnum:]]\+\(/v6\)\? \([.:/[:xdigit:]]\+\|any\) [[:digit:]]\+/\(tcp\|udp\)\( [-_.[:alnum:]]\+\)\?$'

    load-ufw-docker-function ufw-docker--list
    load-ufw-docker-function ufw-docker--status
    ufw-docker--status
}
test-status-internal-assert() {
    test-list-internal-all-rules-assert
}

test-list-internal-all-rules() {
    mock-ufw-status-numbered-foo
    @allow-real grep '# allow [-_.[:alnum:]]\+\(/v6\)\? \([.:/[:xdigit:]]\+\|any\) [[:digit:]]\+/\(tcp\|udp\)\( [-_.[:alnum:]]\+\)\?$'

    load-ufw-docker-function ufw-docker--list
    ufw-docker--list
}
test-list-internal-all-rules-assert() {
    @stdout "[ 3] 172.17.0.3 80/tcp          ALLOW FWD   Anywhere                   # allow foo any 80/tcp bridge"
    @stdout "[ 4] 172.20.0.3 80/tcp          ALLOW FWD   Anywhere                   # allow bar any 80/tcp bar-external"
    @stdout "[ 5] 172.17.0.3 53/udp          ALLOW FWD   Anywhere                   # allow foo any 53/udp foo-internal"
    @stdout "[ 6] 172.17.0.3 53/tcp          ALLOW FWD   Anywhere                   # allow foo any 53/tcp"
    @stdout "[ 7] 172.18.0.2 29090/tcp       ALLOW FWD   Anywhere                   # allow id111111 any 29090/tcp"
    @stdout "[ 8] 172.18.0.2 48080/tcp       ALLOW FWD   Anywhere                   # allow id222222 any 48080/tcp"
    @stdout "[ 9] 172.18.0.2 40080/tcp       ALLOW FWD   Anywhere                   # allow id333333 any 40080/tcp"
    @stdout "[10] 172.18.0.4 8080/tcp        ALLOW FWD   192.168.1.10               # allow baz 192.168.1.10 8080/tcp"
    @stdout "[11] 172.18.0.4 8082/udp        ALLOW FWD   192.168.1.10               # allow baz 192.168.1.10 8082/udp"
    @stdout "[12] 172.18.0.4 8080/tcp        ALLOW FWD   192.168.2.10/24            # allow baz 192.168.2.10/24 8080/tcp"
    @stdout "[13] 172.18.0.4 8081/tcp        ALLOW FWD   192.168.2.10/24            # allow baz 192.168.2.10/24 8081/tcp bridge"
    @stdout "[16] fd00:a:b:deaf::3 80/tcp    ALLOW FWD   Anywhere (v6)              # allow foo/v6 any 80/tcp bridge"
    @stdout "[17] fd05:8f23:c937:2::3 80/tcp ALLOW FWD   Anywhere (v6)              # allow bar/v6 any 80/tcp bar-external"
    @stdout "[18] fd00:a:b:deaf::3 53/udp    ALLOW FWD   Anywhere (v6)              # allow foo/v6 any 53/udp foo-internal"
    @stdout "[19] fd00:a:b:deaf::3 53/tcp    ALLOW FWD   Anywhere (v6)              # allow foo/v6 any 53/tcp"
    @stdout "[20] fd00:a:b:deaf::4 8080/tcp  ALLOW FWD   fd00:a:b:0:cafe::1         # allow baz/v6 fd00:a:b:0:cafe::1 8080/tcp"
    @stdout "[21] fd00:a:b:deaf::4 8080/tcp  ALLOW FWD   fd00:a:b:0:cafe::/80       # allow baz/v6 fd00:a:b:0:cafe::/80 8080/tcp"
    @stdout "[22] fd00:a:b:deaf::4 8081/tcp  ALLOW FWD   fd00:a:b:0:cafe::/80       # allow baz/v6 fd00:a:b:0:cafe::/80 8081/tcp bridge"
}

test-list-internal-rules-by-name() {
    mock-ufw-status-numbered-foo
    @allow-real grep '# allow foo\(/v6\)\? \([.:/[:xdigit:]]\+\|any\) [[:digit:]]\+/\(tcp\|udp\)\( [-_.[:alnum:]]\+\)\?$'

    load-ufw-docker-function ufw-docker--list
    ufw-docker--list foo
}
test-list-internal-rules-by-name-assert() {
    @stdout "[ 3] 172.17.0.3 80/tcp          ALLOW FWD   Anywhere                   # allow foo any 80/tcp bridge"
    @stdout "[ 5] 172.17.0.3 53/udp          ALLOW FWD   Anywhere                   # allow foo any 53/udp foo-internal"
    @stdout "[ 6] 172.17.0.3 53/tcp          ALLOW FWD   Anywhere                   # allow foo any 53/tcp"
    @stdout "[16] fd00:a:b:deaf::3 80/tcp    ALLOW FWD   Anywhere (v6)              # allow foo/v6 any 80/tcp bridge"
    @stdout "[18] fd00:a:b:deaf::3 53/udp    ALLOW FWD   Anywhere (v6)              # allow foo/v6 any 53/udp foo-internal"
    @stdout "[19] fd00:a:b:deaf::3 53/tcp    ALLOW FWD   Anywhere (v6)              # allow foo/v6 any 53/tcp"
}

test-list-internal-rules-by-name-and-udp-protocol() {
    mock-ufw-status-numbered-foo
    @allow-real grep '# allow foo\(/v6\)\? \([.:/[:xdigit:]]\+\|any\) [[:digit:]]\+/udp\( [-_.[:alnum:]]\+\)\?$'

    load-ufw-docker-function ufw-docker--list
    ufw-docker--list foo "" "" udp
}
test-list-internal-rules-by-name-and-udp-protocol-assert() {
    @stdout "[ 5] 172.17.0.3 53/udp          ALLOW FWD   Anywhere                   # allow foo any 53/udp foo-internal"
    @stdout "[18] fd00:a:b:deaf::3 53/udp    ALLOW FWD   Anywhere (v6)              # allow foo/v6 any 53/udp foo-internal"
}


test-list-internal-rules-by-name-port-and-bridge-network() {
    mock-ufw-status-numbered-foo
    @allow-real grep '# allow foo\(/v6\)\? \([.:/[:xdigit:]]\+\|any\) 80/tcp bridge$'

    load-ufw-docker-function ufw-docker--list
    ufw-docker--list foo "" 80 "" bridge
}
test-list-internal-rules-by-name-port-and-bridge-network-assert() {
    @stdout "[ 3] 172.17.0.3 80/tcp          ALLOW FWD   Anywhere                   # allow foo any 80/tcp bridge"
    @stdout "[16] fd00:a:b:deaf::3 80/tcp    ALLOW FWD   Anywhere (v6)              # allow foo/v6 any 80/tcp bridge"
}


test-list-internal-rules-by-name-port-and-udp-protocol() {
    mock-ufw-status-numbered-foo
    @allow-real grep '# allow foo\(/v6\)\? \([.:/[:xdigit:]]\+\|any\) 53/udp\( [-_.[:alnum:]]\+\)\?$'

    load-ufw-docker-function ufw-docker--list
    ufw-docker--list foo "" 53 udp
}
test-list-internal-rules-by-name-port-and-udp-protocol-assert() {
    @stdout "[ 5] 172.17.0.3 53/udp          ALLOW FWD   Anywhere                   # allow foo any 53/udp foo-internal"
    @stdout "[18] fd00:a:b:deaf::3 53/udp    ALLOW FWD   Anywhere (v6)              # allow foo/v6 any 53/udp foo-internal"
}


test-list-internal-fails-with-incorrect-network() {
    mock-ufw-status-numbered-foo
    @allow-real grep '# allow foo\(/v6\)\? any 53/udp incorrect-network$'

    load-ufw-docker-function ufw-docker--list
    ufw-docker--list foo any 53 udp incorrect-network
}
test-list-internal-fails-with-incorrect-network-assert() {
    @fail
}


test-list-internal-rules-by-name-and-source-ip() {
    mock-ufw-status-numbered-foo
    @allow-real grep '# allow baz\(/v6\)\? 192.168.1.10 [[:digit:]]\+/\(tcp\|udp\)\( [-_.[:alnum:]]\+\)\?$'

    load-ufw-docker-function ufw-docker--list
    ufw-docker--list baz 192.168.1.10
}
test-list-internal-rules-by-name-and-source-ip-assert() {
    @stdout "[10] 172.18.0.4 8080/tcp        ALLOW FWD   192.168.1.10               # allow baz 192.168.1.10 8080/tcp"
    @stdout "[11] 172.18.0.4 8082/udp        ALLOW FWD   192.168.1.10               # allow baz 192.168.1.10 8082/udp"
}


test-list-internal-rules-by-name-and-source-subnet() {
    mock-ufw-status-numbered-foo
    @allow-real grep '# allow baz\(/v6\)\? 192.168.2.10/24 [[:digit:]]\+/\(tcp\|udp\)\( [-_.[:alnum:]]\+\)\?$'

    load-ufw-docker-function ufw-docker--list
    ufw-docker--list baz 192.168.2.10/24
}
test-list-internal-rules-by-name-and-source-subnet-assert() {
    @stdout "[12] 172.18.0.4 8080/tcp        ALLOW FWD   192.168.2.10/24            # allow baz 192.168.2.10/24 8080/tcp"
    @stdout "[13] 172.18.0.4 8081/tcp        ALLOW FWD   192.168.2.10/24            # allow baz 192.168.2.10/24 8081/tcp bridge"
}


test-list-internal-rules-by-name-source-and-port() {
    mock-ufw-status-numbered-foo
    @allow-real grep '# allow baz\(/v6\)\? 192.168.2.10/24 8081/tcp\( [-_.[:alnum:]]\+\)\?$'

    load-ufw-docker-function ufw-docker--list
    ufw-docker--list baz 192.168.2.10/24 8081
}
test-list-internal-rules-by-name-source-and-port-assert() {
    @stdout "[13] 172.18.0.4 8081/tcp        ALLOW FWD   192.168.2.10/24            # allow baz 192.168.2.10/24 8081/tcp bridge"
}


test-list-internal-rules-by-name-source-port-and-udp-protocol() {
    mock-ufw-status-numbered-foo
    @allow-real grep '# allow baz\(/v6\)\? 192.168.1.10 8082/udp\( [-_.[:alnum:]]\+\)\?$'

    load-ufw-docker-function ufw-docker--list
    ufw-docker--list baz 192.168.1.10 8082 udp
}
test-list-internal-rules-by-name-source-port-and-udp-protocol-assert() {
    @stdout "[11] 172.18.0.4 8082/udp        ALLOW FWD   192.168.1.10               # allow baz 192.168.1.10 8082/udp"
}


test-list-internal-rules-by-name-source-port-protocol-and-network() {
    mock-ufw-status-numbered-foo
    @allow-real grep '# allow baz\(/v6\)\? 192.168.2.10/24 8081/tcp bridge$'

    load-ufw-docker-function ufw-docker--list
    ufw-docker--list baz 192.168.2.10/24 8081 tcp bridge
}
test-list-internal-rules-by-name-source-port-protocol-and-network-assert() {
    @stdout "[13] 172.18.0.4 8081/tcp        ALLOW FWD   192.168.2.10/24            # allow baz 192.168.2.10/24 8081/tcp bridge"
}


test-list-internal-rules-by-name-and-port() {
    mock-ufw-status-numbered-foo
    @allow-real grep '# allow foo\(/v6\)\? \([.:/[:xdigit:]]\+\|any\) 80/tcp\( [-_.[:alnum:]]\+\)\?$'

    load-ufw-docker-function ufw-docker--list
    ufw-docker--list foo "" 80
}
test-list-internal-rules-by-name-and-port-assert() {
    @stdout "[ 3] 172.17.0.3 80/tcp          ALLOW FWD   Anywhere                   # allow foo any 80/tcp bridge"
    @stdout "[16] fd00:a:b:deaf::3 80/tcp    ALLOW FWD   Anywhere (v6)              # allow foo/v6 any 80/tcp bridge"
}


test-list-number-internal() {
    @mocktrue ufw-docker--list foo any 53 udp

    load-ufw-docker-function ufw-docker--list-number
    ufw-docker--list-number foo any 53 udp
}
test-list-number-internal-assert() {
    sed -e 's/^\[[[:blank:]]*\([[:digit:]]\+\)\].*/\1/'
}


test-delete-internal-does-nothing-for-empty-result() {
    @mock ufw-docker--list-number webapp any 80 tcp === @stdout ""
    @mockpipe sort -rn

    load-ufw-docker-function ufw-docker--delete
    ufw-docker--delete webapp any 80 tcp
}
test-delete-internal-does-nothing-for-empty-result-assert() {
    @do-nothing
}


test-delete-internal-all-rules() {
    @mock ufw-docker--list-number webapp any 80 tcp === @stdout 5 8 9
    @mockpipe sort -rn
    @ignore echo

    load-ufw-docker-function ufw-docker--delete
    ufw-docker--delete webapp any 80 tcp
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
