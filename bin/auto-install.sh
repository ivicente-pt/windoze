#!/bin/bash

TARGET="/opt/aevh"
AEVH_TOKEN=".aevh_token"
WINDOZE_TOKEN=".windoze_token"


find_github_token() {
    local token_file="${1:-}" found_token="" mount_points
    [[ -z "$token_file" ]] && return 1
    mapfile -t mount_points < <(lsblk -no MOUNTPOINT | grep -v "^$")
    mount_points+=("." "$HOME")

    for mnt in "${mount_points[@]}"; do
        [[ ! -r "$mnt/$token_file" ]] && continue
        found_token=$(tr -d '\r\n ' < "$mnt/$token_file")
        [[ -n "$found_token" ]] && { echo "$found_token"; return 0; }
    done
    return 1
}

download_repo() {
    local repo="${1:-}" token="${2:-}"
    [[ -z "$repo" || -z "$token" ]] && return 1
    local owner="ivicente-pt" branch="main" target
    target="/tmp/$repo"
    mkdir -p "$target"
   
    curl -H "Authorization: token $token" \
         -L "https://api.github.com/repos/$owner/$repo/tarball/$branch" \
         | tar -xzC "$target" --strip-components=1
}

install_windoze() {
    token=$(find_github_token "$WINDOZE_TOKEN")
    [[ -z "$token" ]] && { echo "Erro: Ficheiro $WINDOZE_TOKEN não encontrado"; exit 1; }
    download_repo windoze "$token"
    sudo cp -r /tmp/windoze/* "$TARGET"
    rm -rf /tmp/windoze
}

install_aevh_lib() {
    token=$(find_github_token "$AEVH_TOKEN")
    [[ -z "$token" ]] && { echo "Erro: Ficheiro $AEVH_TOKEN não encontrado"; exit 1; }
    download_repo aevh "$token"
    sudo cp -r /tmp/aevh/* "$TARGET"
    rm -rf /tmp/aevh
}

install_windoze
install_aevh_lib
"$TARGET"/bin/windoze full
