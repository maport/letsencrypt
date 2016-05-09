#!/bin/bash
set -e

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"


show_help () {
  echo 'Usage:
  runle generate [--test] <state_dir> <email> <domain>
    generate certificate storing/using state in state_dir
  runle renew [--test] <state_dir> <domain>
    renew previously generate certificate if it is due for renewal
  runle appengine <state_dir> <domain>
    display previously generated certificate for pasting into appengine console
' >&2
}


error () {
    local msg="$1"
    [ -z "$msg" ] || echo "ERROR: $msg" 
    show_help
    exit 1
}


build_docker () {
    docker build --tag 'codesimple/letsencrypt' "$SCRIPT_DIR/docker_ctx"
}


run_docker () {
    local cfg_dir="$1"
    shift
    docker run -it --rm -v "$cfg_dir:/etc/letsencrypt:rw" 'codesimple/letsencrypt' "$@"
}


gen_cert () {
    local cfg_dir="$1"
    local email="$2" # or 'renew'
    local domain="$3"
    local testing="$4"
    local cmd=('./letsencrypt-auto' 'certonly' '--no-self-upgrade' '--manual'
               '--email' "$email" '--domains' "$domain" '--text' '--agree-tos' '--manual-public-ip-logging-ok')
    if [ "$email" = 'renew' ]; then
       cmd+=('--keep-until-expiring')
    fi
    if [ "$testing" = 'test' ]; then
       cmd+=('--test-cert')
    fi
    run_docker "$cfg_dir" "${cmd[@]}"
}


show_for_appengine () {
    local cfg_dir="$1"
    local domain="$2"
    echo "Private key is:"
    local cmd=('openssl' 'rsa' '-inform' 'pem' '-in' "/etc/letsencrypt/live/$domain/privkey.pem" '-outform' 'pem')
    run_docker "$cfg_dir" "${cmd[@]}"
    echo "Certificate is:"
    cmd=('cat' "/etc/letsencrypt/live/$domain/fullchain.pem")
    run_docker "$cfg_dir" "${cmd[@]}"
}


build_docker

[ "$#" -gt 0 ] || error 

case "$1" in

  generate)
    testing=""
    if [ "$2" = '--test' ]; then
        testing='test'
        shift
    fi 
    [ "$#" -eq 4 ] || error 'Expected 4 arguments' 
    cfg_dir="$(readlink -f "$2")"
    email="$3"
    domain="$4"
    mkdir -p "$cfg_dir"
    gen_cert "$cfg_dir" "$email" "$domain" "$testing"
    ;;

  renew)
    testing=""
    if [ "$2" = '--test' ]; then
        testing='test'
        shift
    fi 
    [ "$#" -eq 3 ] || error 'Expected 3 arguments' 
    cfg_dir="$(readlink -f "$2")"
    domain="$3"
    [ -d "$cfg_dir" ] || error 'State directory does not exist'
    gen_cert "$cfg_dir" renew "$domain" "$testing"
    ;;

  appengine)
    [ "$#" -eq 3 ] || error 'Expected 3 arguments'
    cfg_dir="$(readlink -f "$2")"
    domain="$3"
    [ -d "$cfg_dir" ] || error 'State directory does not exist'
    show_for_appengine "$cfg_dir" "$domain"
    ;;

  *)
    error
    ;;

esac

