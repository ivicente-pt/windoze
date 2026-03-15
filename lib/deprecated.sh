#!/usr/bin/env bash
set -euo pipefail

# aevh-tools v1.2 2026-01-01

# Devolve true se for para instalar o XFCE4
is_xfce4() { [[ "${AEVH_GUI,,}" == "xfce4" ]] || is_hp7800 ; }

install_piper() {
    local install_dir="/opt/aevh/piper"
    local bin_url="https://github.com/rhasspy/piper/releases/download/2023.11.14-2/piper_linux_x86_64.tar.gz"
    local voice_url="https://huggingface.co/rhasspy/piper-voices/blob/main/pt/pt_PT/tugão/medium/pt_PT-tugão-medium.onnx"
    local json_url="https://huggingface.co/rhasspy/piper-voices/resolve/v1.0.0/pt/pt_PT/tugão/medium/pt_PT-tugão-medium.onnx.json"
    mkdir -p "$install_dir"
    cd "$install_dir" || return 1
    if [ ! -f "piper" ]; then
        info_exec "A transferir binário Piper..." wget -q -O piper.tar.gz "$bin_url"
        tar -xzf piper.tar.gz --strip-components=1 # Remove a pasta 'piper/' extra
        rm piper.tar.gz
        chmod +x piper
    fi
    if [ ! -f "pt_PT-tugao-medium.onnx" ]; then
        wget "$voice_url"
        wget "$json_url"
    fi
    ln -sf "$install_dir/piper" /usr/local/bin/piper
}


enable_flatpak() {
    apt_install flatpak
    flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
    flatpak install --system flathub org.onlyoffice.desktopeditors
    flatpak install --system flathub org.libreoffice.LibreOffice
    flatpak install --system flathub com.wps.Office
    flatpak install --system flathub com.collaboraoffice.Office
}

# Definir as opções do Cinnamon
set_cinnamon_options() {
    info "A definir as opções visuais do Cinnamon..."
    
    # Função auxiliar
    gset() { gsettings set "$1" "$2" "$3"; }
    
    gset "org.cinnamon.desktop.wm.preferences"  "theme"                 "$THEME"
    gset "org.cinnamon.desktop.interface"       "gtk-theme"             "$THEME"
    gset "org.cinnamon.desktop.interface"       "icon-theme"            "$ICON"
    gset "org.cinnamon.desktop.interface"       "cursor-theme"          "Adwaita"
    gset "org.cinnamon.theme"                   "name"                  "$THEME"
    gset "org.cinnamon.desktop.background"      "picture-uri"           "file://$WALLPAPER"
    gset "org.cinnamon.desktop.interface"       "font-name"             "$FONT"
    gset "org.nemo.desktop"                     "show-desktop-icons"    "true"
    gset "org.nemo.desktop"                     "computer-icon-visible" "true"
    gset "org.nemo.desktop"                     "trash-icon-visible"    "true"
    gset "org.nemo.desktop"                     "home-icon-visible"     "true"
    local config="$HOMEDIR/.config/cinnamon/spices/menu@cinnamon.org/0.json"
    local label=""
    ! command -v jq >/dev/null && { warn "jq não instalado. Menu Cinnamon não configurado."; return 1; }
    [[ ! -f "$config" ]] && { warn "Ficheiro de configuração não encontrado: $config"; return 1; }
    jq ".\"menu-icon\".value = \"$LOGO\" |
        .\"menu-label\".value = \"$label\" |
        .\"menu-custom\".value = true" \
        "$config" > "$config.tmp"
    if [[ $? -eq 0 ]]; then
        mv "$config.tmp" "$config"
    else
        warn "Falha ao editar JSON com jq."
        rm -f "$config.tmp"
    fi
}
