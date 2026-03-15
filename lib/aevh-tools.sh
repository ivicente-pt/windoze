#!/usr/bin/env bash
set -euo pipefail

# aevh-tools v1.2 2026-01-01

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AEVH_ROOT="$(dirname "$SCRIPT_DIR")"

# shellcheck disable=SC1091
source "$AEVH_ROOT/lib/ice-tools.sh"
# shellcheck disable=SC1091
source "$AEVH_ROOT/config/aevh.conf"
# shellcheck disable=SC1091
source "$AEVH_ROOT/lib/deprecated.sh"

# Alguns caminhos necessários
AEVH_BIN=${AEVH_BIN:-"/opt/aevh/bin"}
AEVH_CONF=${AEVH_CONF:-"/opt/aevh/config"}
AEVH_DATA=${AEVH_DATA:-"/opt/aevh/data"}
AEVH_LOG=${AEVH_LOG:-"/opt/aevh/log"}
AEVH_LOGFILE=${AEVH_LOGFILE:-"$AEVH_LOG/aevh.log"}
mkdir -p "$AEVH_BIN" "$AEVH_CONF" "$AEVH_DATA" "$AEVH_LOG"

# shellcheck disable=SC2034
ICE_LOGFILE="$AEVH_LOGFILE"

# Devolve o nome da máquina
get_machine_name() {
    local dmi_prod="/sys/class/dmi/id/product_name"
    local dmi_board="/sys/class/dmi/id/board_name"
    local arm_model="/sys/firmware/devicetree/base/model"
    [[ -f "$dmi_prod" ]] && { cat "$dmi_prod"; return 0; }
    [[ -f "$dmi_board" ]] && { cat "$dmi_board"; return 0; }
    [[ -f "$arm_model" ]] && { tr -d '\0' < "$arm_model"; return 0; }
    uname -m
}

# Deteta se a máquina é uma HP 7800
is_hp7800 () { [[ $(get_machine_name) == *"HP Compaq dc7800"* ]]; }

# Apresentar uma notificação
notify() {
    local notify_bin="$AEVH_BIN"/notify-all
    if [[ -x "$notify_bin" ]]; then
        "$notify_bin" "$@"
    else
        error "Executável não encontrado: $notify_bin"
    fi
}

# Pede confirmação
confirm() {
    local msg="$1"
    local title="$2"
    msg+="\n\nTem a certeza?"
    dialog --title "$title" --yesno "$msg" 12 60
    return $? # Retorna 0 se Sim, 1 se Não
}
