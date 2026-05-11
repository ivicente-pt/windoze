#!/usr/bin/env bash

# MAGIC

set -euo pipefail

AEVH_LIB="/opt/aevh/lib/aevh-lib.sh"
[[ -f "$AEVH_LIB" ]] && source "$AEVH_LIB" || true
[[ "${AEVH_LIB_LOADED:-0}" != "1" ]] && { echo "Falha a carregar $AEVH_LIB" >&2 ; exit 1; }

auto_optimize_preload() {
    [[ ${DEBUG:-0} -eq 1 ]] && log_info "${FUNCNAME[1]}() -> ${FUNCNAME[0]}()"
    local override_dir="/etc/systemd/system/preload.service.d" disk_type
    disk_type=$(get_disk_type) || true
    if [[ "$disk_type" == "HDD" ]]; then 
        apt_install preload
        mkdir -p "$override_dir"
        copy_safe "$AEVH_CONF/systemd/override.conf" "$override_dir"
        systemctl daemon-reload
        systemctl restart --no-block preload
        return 0
    fi
    # Se não é HDD
    apt_purge preload
    rm -rf "$override_dir"
    apt_cmd autopurge
}

auto_optimize_picom() {
    [[ ${DEBUG:-0} -eq 1 ]] && log_info "${FUNCNAME[1]}() -> ${FUNCNAME[0]}()"
    local conf_file="$AEVH_CONF/windoze.conf" picom="1"
    [[ "$(get_cpu_benchmark_multithread)" -ge 100 ]] || picom=0
    set_config_value "$conf_file" "PICOM" "$picom"
}

auto_optimize_zram() {
    [[ ${DEBUG:-0} -eq 1 ]] && log_info "${FUNCNAME[1]}() -> ${FUNCNAME[0]}()"
    local zram_config="/etc/default/zramswap" size=60 algo="zstd"
    apt_install zram-tools
    systemctl stop zramswap 2>/dev/null
    [[ "$(get_cpu_benchmark_multithread)" -le 100 ]] && { size=50; algo="lz4"; }
    cat << EOF > "$zram_config"
ALLOCATION_STRATEGY=percent
PERCENT=$size
COMPRESSION_ALGORITHM="$algo"
PRIORITY=100
EOF
    systemctl restart zramswap 2>/dev/null || log_warn "Não foi possível reiniciar zramswap"

    local sys_file="/etc/sysctl.d/99-swappiness.conf"
    mkdir -p "$(dirname "$sys_file")"
    [[ -f "$sys_file" ]] || touch "$sys_file" 
    set_config_value "$sys_file" "vm.swappiness" "100"
    set_config_value "$sys_file" "vm.vfs_cache_pressure" "50"
    sysctl -p "$sys_file" >/dev/null
}

auto_optimize_logs() {
    [[ ${DEBUG:-0} -eq 1 ]] && log_info "${FUNCNAME[1]}() -> ${FUNCNAME[0]}()"
    local conf_dir="/etc/systemd/journald.conf.d"
    local conf_file="$conf_dir/99-aevh-logs.conf" storage="volatile"

    [[ $(get_ram_size) -le 2 ]] && storage="persistent"
    mkdir -p "$conf_dir"
    cat << EOF > "$conf_file"
[Journal]
Storage=$storage
SystemMaxUse=50M
RuntimeMaxUse=50M
MaxRetentionSec=2d
EOF

    (
        journalctl --vacuum-size=50M --vacuum-time=2d >/dev/null 2>&1
        systemctl restart systemd-journald
    ) &

    log_info "Otimização de logs concluída."
}

auto_optimize_init() {
    [[ ${DEBUG:-0} -eq 1 ]] && log_info "${FUNCNAME[1]}() -> ${FUNCNAME[0]}()"
#    sed -i 's/^[# ]*MODULES=.*/MODULES=dep/' "/etc/initramfs-tools/initramfs.conf"
#    update-initramfs -u >/dev/null 2>&1
}

auto_optimize() {
    [[ ${DEBUG:-0} -eq 1 ]] && log_info "${FUNCNAME[1]}() -> ${FUNCNAME[0]}()"
    log_info "A otimizar o sistema"
    systemctl disable --now NetworkManager-wait-online.service ModemManager.service 2>/dev/null || true
    systemctl mask --now avahi-daemon.service avahi-daemon.socket e2scrub_reap.service 2>/dev/null || true
    systemctl daemon-reload
    auto_optimize_preload
    auto_optimize_picom
    auto_optimize_zram
    auto_optimize_logs
    auto_optimize_init
    apt_cmd autopurge
    log_info "Serviços otimizados"
}

add_grub_params() {
    [[ ${DEBUG:-0} -eq 1 ]] && log_info "${FUNCNAME[1]}() -> ${FUNCNAME[0]}()"
    (( $# < 2 )) && return 0 
    local conf_file="${1:-}" params="${*:2}"
    if [[ -f "$conf_file" ]] && grep -qF "$params" "$conf_file"; then
        return 0
    fi
    mkdir -p "$(dirname "$conf_file")" || { log_warn "Erro ao criar o diretório para: $conf_file"; return 1; }
    echo "GRUB_CMDLINE_LINUX_DEFAULT=\"\$GRUB_CMDLINE_LINUX_DEFAULT $params\"" > "$conf_file"
    update-grub || log_warn "Não consegui atualizar o GRUB"
}

auto_hp7800() {
    [[ ${DEBUG:-0} -eq 1 ]] && log_info "${FUNCNAME[1]}() -> ${FUNCNAME[0]}()"
    local conf_file="/etc/default/grub.d/98-hp7800-fix.cfg" e1000="$AEVH_BIN/auto-patch-e1000.sh"
    # lax para sensores, disable pstate para usar o driver legacy melhorado
    [[ -f "$e1000" ]] && "$e1000"
    local params="acpi_enforce_resources=lax intel_pstate=disable video=SVIDEO-1:d"
    add_grub_params "$conf_file" "$params"
}

setup_autorotate_service() {
    [[ ${DEBUG:-0} -eq 1 ]] && log_info "${FUNCNAME[1]}() -> ${FUNCNAME[0]}()"
    local service_file="/etc/systemd/system/autorotate.service"

    cat <<EOF > "$service_file"
[Unit]
Description=Serviço de Auto-rotação para Classmate
After=lightdm.service
Wants=iio-sensor-proxy.service

[Service]
Type=simple
ExecStart=/opt/aevh/bin/classmate-autorotate.sh
Restart=always
RestartSec=5
User=root

[Install]
WantedBy=graphical.target
EOF

    systemctl daemon-reload
    systemctl enable autorotate.service
    systemctl start autorotate.service
}

auto_classmate() {
    [[ ${DEBUG:-0} -eq 1 ]] && log_info "${FUNCNAME[1]}() -> ${FUNCNAME[0]}()"
    apt_install iio-sensor-proxy || true
    setup_autorotate_service
    local ldm_conf="/etc/lightdm/lightdm.conf.d/99-classmate-rotation.conf"
    local script_path="$AEVH_BIN/classmate-monitor-normal.sh"
    if [[ -f "$script_path" ]]; then
        chmod +x "$script_path"
        mkdir -p "$(dirname $ldm_conf)"
        cat <<EOF > "$ldm_conf"
[Seat:*]
display-setup-script=$script_path
EOF
    fi
    
    local conf_file="/etc/default/grub.d/99-braswell-fix.cfg"
    local params="intel_idle.max_cstate=1 i915.enable_dc=0 i915.enable_rc6=0"
    add_grub_params "$conf_file" "$params"
}

auto_magic() {
    [[ ${DEBUG:-0} -eq 1 ]] && log_info "${FUNCNAME[1]}() -> ${FUNCNAME[0]}()"
    auto_optimize
    if is_hp7800; then
        log_info "Detetado HP 7800"
        auto_hp7800
    fi
    if is_classmate; then
        log_info "Detetado Intel Classmate"
        auto_classmate
    fi
}

usage() {
    echo "magic [auto|hp7800|classmate]"
}

main() {
    apt_update
    apt_upgrade
    local opt="${1:-}"
    opt="${opt,,}"
    case "$opt" in
        "auto")      auto_magic ;;
        "hp7800")    auto_hp7800 ;;
        "classmate") auto_classmate ;;
        "")          usage ;;
    esac
}

need_root
main "$@"