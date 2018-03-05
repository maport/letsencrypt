#!/bin/bash
set -e

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
LOG_DIR="/tmp/le_logs"


show_help () {
  echo 'Usage:
  runle generate [--test] <state_dir> <email> <domain>
    generate certificate storing/using state in state_dir
  runle renew [--test] <state_dir> <main-domain>
    renew previously generate certificate if it is due for renewal
  runle display <state_dir> <main-domain>
    display previously generated certificate in PEM format
  runle gitlab <state_dir> <main-domain> <site_id> <domain>
    Set the certificate for the GitLab site to the previously generated certificate
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
    mkdir -p "$LOG_DIR"
    docker run -it --rm -v "$LOG_DIR:/var/log/letsencrypt:rw" -v "$cfg_dir:/etc/letsencrypt:rw" 'codesimple/letsencrypt' "$@"
}


gen_cert () {
    local cfg_dir="$1"
    local email="$2" # or 'renew'
    local domain="$3"
    local testing="$4"
    local cmd=('certbot' 'certonly' '--no-self-upgrade' '--manual' '--preferred-challenges' 'dns'
               '--domains' "$domain" '--text' '--agree-tos' '--manual-public-ip-logging-ok')
    if [ "$email" = 'renew' ]; then
       cmd+=('--keep-until-expiring')
    else
       cmd+=('--email' "$email")
    fi
    if [ "$testing" = 'test' ]; then
       cmd+=('--test-cert')
    fi
    run_docker "$cfg_dir" "${cmd[@]}"
}


get_key () {
    local cfg_dir="$1"
    local domain="$2"
    local cmd=('openssl' 'rsa' '-inform' 'pem' '-in' "/etc/letsencrypt/live/$domain/privkey.pem" '-outform' 'pem')
    # AWK is used to skip the 'writing RSA key' message openssl outputs at the start
    local key=$(run_docker "$cfg_dir" "${cmd[@]}" | awk '/-----/,EOF { print $0 }')
    printf '%s' "$key"
}


get_cert () {
    local cfg_dir="$1"
    local domain="$2"
    local cmd=('cat' "/etc/letsencrypt/live/$domain/fullchain.pem")
    local cert=$(run_docker "$cfg_dir" "${cmd[@]}")
    printf '%s' "$cert"
}


display_pem () {
    local cfg_dir="$1"
    local domain="$2"
    printf 'Private key is:\n%s\n' "$(get_key "$cfg_dir" "$domain")"
    printf 'Certificate is:\n%s\n' "$(get_cert "$cfg_dir" "$domain")"
}


gitlab_pages () {
    local cfg_dir="$1"
    local cfg_domain="$2"
    local site_id="$3"
    local domain="$4"
    local gitlab_token="$5"
    local key="$(get_key "$cfg_dir" "$cfg_domain")"
    local cert="$(get_cert "$cfg_dir" "$cfg_domain")"
    local cmd=(
        'curl' '--request' 'PUT' '--header' "PRIVATE-TOKEN: $gitlab_token"
        '--form' "certificate=$cert"
        '--form' "key=$key"
        "https://gitlab.com/api/v4/projects/$site_id/pages/domains/$domain"
    )
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

  display)
    [ "$#" -eq 3 ] || error 'Expected 3 arguments'
    cfg_dir="$(readlink -f "$2")"
    domain="$3"
    [ -d "$cfg_dir" ] || error 'State directory does not exist'
    display_pem "$cfg_dir" "$domain"
    ;;

  gitlab)
    [ "$#" -eq 5 ] || error 'Expected 5 arguments'
    cfg_dir="$(readlink -f "$2")"
    cfg_domain="$3"
    site_id="$4"
    domain="$5"
    [ -d "$cfg_dir" ] || error 'State directory does not exist'
    gitlab_token="$(cat "$(dirname "$cfg_dir")/gitlab_token.cfg")"
    gitlab_pages "$cfg_dir" "$cfg_domain" "$site_id" "$domain" "$gitlab_token"
    ;;

  *)
    error
    ;;

esac

