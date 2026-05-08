#!/usr/bin/env bash

# MAGIC

set -euo pipefail

AEVH_LIB="/opt/aevh/lib/aevh-lib.sh"
[[ -f "$AEVH_LIB" ]] && source "$AEVH_LIB" || true
[[ "${AEVH_LIB_LOADED:-0}" != "1" ]] && { echo "Falha a carregar $AEVH_LIB" >&2 ; exit 1; }

auto_magic() {
    echo Magic
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