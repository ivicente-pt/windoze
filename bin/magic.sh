#!/usr/bin/env bash

# MAGIC

set -euo pipefail

AEVH_LIB="/opt/aevh/lib/aevh-lib.sh"
[[ -f "$AEVH_LIB" ]] && source "$AEVH_LIB" || true
[[ "${AEVH_LIB_LOADED:-0}" != "1" ]] && { echo "Falha a carregar $AEVH_LIB" >&2 ; exit 1; }

auto_hp7800() {
    echo "HP 7800..."
}

auto_classmate() {
    echo "Classmate..."
}

auto_magic() {
    if is_hp7800; then
        log_info "Detetado HP 7800"
        auto_hp7800
    fi
    if is_classmate; then
        log_info "Detetato Intel Classmate"
        auto_classmate
    fi
}

usage() {
    echo "magic [auto]"
}

main() {
    local opt="${1:-}"
    opt="${opt,,}"
    case "$opt" in
        "auto")
            auto_magic
        ;;
        "")
            usage
        ;;
    esac
}

main "$@"