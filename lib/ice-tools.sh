#!/bin/bash
# ice-tools v1.17 2025-12-11
# Funções úteis

## Lista de Funções Definidas no Script `tools`, agrupadas por categoria
## LOG
#   clean_msg(): limpa as escape sequences
#   log(): Regista uma mensagem no ficheiro de log especificado por `ICE_LOGFILE`.
#   info(): Mostra uma mensagem informativa no ecrã e regista-a no log.
#   warn(): Mostra uma mensagem de aviso no ecrã e regista-a no log.
#   error(): Mostra uma mensagem de erro e regista-a no log
#   fatal(): Mostra uma mensagem de erro, regista-a no log e termina o script com falha.
#   bye(): Mostra uma mensagem informativa, regista-a no log e termina o script com sucesso.
#   speak(): Fala o texto
#   speak_log(): Lê uma linha de log ignorando a data e o tipo
## PACOTES
#   apt_cmd(): Executa o apt em modo não interativo.
#   apt_update(): Atualiza os repositórios
#   apt_upgrade(): Atualiza os pacotes do sistema.
#   apt_install(): Instala pacotes, se necessário atualiza os repositórios;
#   apt_purge(): Remove pacotes obsoletos.
#   apt_fix(): Tenta corrigir alguns problemas com o APT.
## COMANDOS
#   assert(): Avalia o 2.º parâmetro, se for falso gera um erro e mostra o 1.º parâmetro..
#   check(): Semelhante a assert, mas gera só um aviso
#   info_exec(): Mostra o 1.º parâmetro e executa o comando
#   warn_ok_exec(): Executa o comando, se mal sucedido faz um aviso com $1, se bem mostra $2
# ROOT & USERS
#   is_root(): Verifica se o script está a ser executado como root
#   getroot(): Tenta re-executar o script com privilégios de root usando `sudo`.
#   run_as(): Executa um comando como outro utilizador
#   get_home(): Devolve a homedir do user $1
# STRING e TECLADO
#   keywait(): Pausa a execução do script e espera que o utilizador pressione uma tecla.
#   trim(): Remove espaços em branco (início e fim) e normaliza múltiplos espaços no meio de uma string para um único espaço.
# FICHEIROS DE CONFIGURAÇÃO
#   config_key_exists(): Verifica se uma chave específica existe num ficheiro de configuração.
#   get_config_value(): Obtém o valor associado a uma chave num ficheiro de configuração.
#   set_config_value(): Define ou atualiza o valor de uma chave num ficheiro de configuração, com sanitização da chave e do valor.
#   is_debian12(): Devolve true se for Debian 12
## NET
#   test_port(): Testa a ligação ao porto $2 no ip $1
#   is_valid_hostname(): Verifica se $1 é um hostname válido
## FICHEIRO E DISCO
#   copy_check(): Verifica se $1 existe e se existir copia para a dir $2
#   get_disk_type(): Devolve o tipo de disco (hdd,ssd,nvme) da diretoria $1
## MEDIA
#   hdmi_connected(): Verifica se HDMI está ligado
#   change_audio_output(): Muda o output de áudio para $1 (nome amigável $2)


## LOG

# Por pré-definição guarda os logs em /tmp
ICE_LOGFILE="/tmp/ice-tools.log"
ICE_DEBUG=0
# Subsistema de fala
ICE_SPEAK=1
ICE_SPEAK_WAIT=5
ICE_LOG_SPEAK=0
SPEAK_BUSY="/tmp/speak_busy.tmp"
# piper
PIPER_BIN="/opt/aevh/piper/piper"
PIPER_MODEL="/opt/aevh/piper/pt_PT-tugao-medium.onnx"

# Cores
C_RED="\033[31m"
C_YELLOW="\033[33m"
C_GREEN="\033[32m"
C_BLUE="\033[34m"
C_MAGENTA="\033[35m"
C_RESET="\033[0m"

# Diz o texto em voz alta
speak() {
    local msg="$(remove_tags "$*")"
    local SPEAK_BUSY="${SPEAK_BUSY:-/tmp/voice_lock}"
    [[ "$ICE_SPEAK" -eq 0 ]] && return 0
    local timeout=0
    while [[ -f "$SPEAK_BUSY" ]]; do
        sleep 0.1
        ((timeout++))
        # Se esperar mais de $ICE_SPEAK_WAIT décimos de seg., desiste
        [[ $timeout -ge $ICE_SPEAK_WAIT ]] && return 1 
    done
    touch "$SPEAK_BUSY"
    (
        if [[ -x "$PIPER_BIN" && -f "$PIPER_MODEL" ]]; then
            echo "$msg" | "$PIPER_BIN" --model "$PIPER_MODEL" --output_raw 2>/dev/null | aplay -q -r 22050 -f S16_LE -t raw > /dev/nul 2>&1 
        elif command -v espeak-ng >/dev/null 2>&1; then
            espeak-ng -v pt+f2 -s 130 "$msg" >/dev/null 2>&1
        elif command -v espeak >/dev/null 2>&1; then
            espeak -v pt-pt+f2 -s 130 "$msg" >/dev/null 2>&1
        fi
        rm "$SPEAK_BUSY"
    ) &
}

# Limpa as escape sequences da mensagem
clean_msg() { printf "%s" "$*" | sed 's/\x1b\[[0-9;]*m//g'; }

# Cria uma entrada no log
log() {
    [[ -z "$ICE_LOGFILE" ]] && return 1
    local msg=$(clean_msg "$@")
    [[ -w "$ICE_LOGFILE" ]] && printf "[%s] %s\n" "$(date +"%Y-%m-%d %T")" "$msg" >> "$ICE_LOGFILE" 2>/dev/null
    [[ $ICE_LOG_SPEAK -eq 1 ]] && speak "$msg"
}

# Mostra uma informação e regista no log
info() { local msg="$*"; printf "[${C_BLUE}INFO${C_RESET}] %s\n" "$msg"; log "[INFO] $msg"; }

# Mostra um aviso e regista no log
warn() { local msg="$*"; printf "[${C_YELLOW}WARN${C_RESET}] %s\n" "$msg"; log "[WARN] $msg"; }

# Mostra um erro e regista no log
error() { local msg="$*"; printf "[${C_RED}FAIL${C_RESET}] %s\n" "$msg" >&2; log "[FAIL] $msg"; }

# Mostra um erro, regista no log e termina o script com erro
fatal() { local msg="$*"; printf "[${C_MAGENTA}DEAD${C_RESET}] %s\n" "$msg" >&2; log "[DEAD] $msg"; exit 1; }

# Mostra uma informação, regista no log e termina o script sem erro
bye() { info "$*"; exit 0; }

# Remove texto dentro de [] de uma string
remove_tags() {
    local input="${*:-$(cat -)}"
    echo "$input" | sed 's/\[[^]]*\]//g' | trim
}

# Lê o texto de uma linha de log "[data hora] [tipo] texto"
speak_log() {
    local line="$(remove_tags "$*")"
    # falta aqui o sed para retirar a data hora e tipo do texto
    local text="${line:29}"
    [[ -n "$text" ]] && speak "$text"
}

## PACOTES

# Executar um apt
apt_cmd() {
    local comm="$1"
    shift 1
    env DEBIAN_FRONTEND=noninteractive apt-get -yqq "$comm" "$@"
}
apt_update() { apt_cmd update --allow-releaseinfo-change; }
apt_upgrade() { apt_cmd full-upgrade --fix-broken ; }
# shellcheck disable=SC2120
apt_install() {
    local to_install=()
    local cache="/var/cache/apt/pkgcache.bin"
    local max_age=60
    if [[ -d "$cache" ]] && [[ ! -n "$(find "$cache" -maxdepth 0 -mmin -"$max_age" 2>/dev/null)" ]]; then
        apt_update
    fi
    if [[ "$#" -eq 0 ]]; then
        apt_cmd install --fix-broken --no-install-recommends
        return 0
    fi
    for pkg in "$@"; do
        if ! dpkg-query -W -f='${Status}' "$pkg" 2>/dev/null | grep -q "install ok installed"; then
            to_install+=("$pkg")
        fi
    done
    if [[ ${#to_install[@]} -gt 0 ]]; then
        apt_cmd install --fix-broken --no-install-recommends "${to_install[@]}"
        return $?
    else
        info "Não há pacotes novos para instalar"
    fi
}
apt_purge() { apt_cmd purge "$@" ; }
apt_fix() {
    dpkg --configure -a
    apt_install
    apt_cmd autoremove
}

## COMANDOS

# Mostra a mensagem $1 e para a execução se o comando $2... der erro 
assert() {
    [[ $ICE_DEBUG -eq 1 ]] && log "${FUNCNAME[1]}() -> ${FUNCNAME[0]}(): $*"
    [[ "$#" -lt 2 ]] && { warn "assert(): Uso incorreto"; return 1; }
    local msg="$1"
    shift 1
    "$@" || { fatal "$msg (código: $?)"; }
}

# Mostra o warning $1 se $2... der erro
check() {
    [[ $ICE_DEBUG -eq 1 ]] && log "${FUNCNAME[1]}() -> ${FUNCNAME[0]}(): $*"
    [[ "$#" -lt 2 ]] && { warn "check(): Uso incorreto"; return 1; }
    local msg="$1"
    shift 1
    "$@" || { warn "$msg (código $?)"; return 1; }
}

# Mostra a info $1 e executa $2-
info_exec() {
    [[ $ICE_DEBUG -eq 1 ]] && log "${FUNCNAME[1]}() -> ${FUNCNAME[0]}(): $*"
    [[ "$#" -lt 2 ]] && { warn "info_exec(): Uso incorreto"; return 1; }
    local msg="$1"
    shift 1
    info "$msg"
    "$@"
    return $?
}

# Executa o comando $3..., se erro mostra warning $1, se ok mostra info $2
warn_ok_exec() {
    [[ $ICE_DEBUG -eq 1 ]] && log "${FUNCNAME[1]}() -> ${FUNCNAME[0]}(): $*"
    [[ "$#" -lt 3 ]] && { warn "warn_ok_exec(): Uso incorreto"; return 1; }
    local msg_fail="$1"
    local msg_ok="$2"
    shift 2
    if "$@"; then
        info "$msg_ok"
    else
        warn "$msg_fail"
        return 1
    fi
}

## ROOT

# Verifica se é root (ou um user com sudo)
is_root() { [[ $EUID -eq 0 ]]; }

# Tenta obter o root
getroot() {
    is_root && return 0
    command -v sudo >/dev/null || fatal "getroot(): 'sudo' não está instalado."
    warn "A elevar privilégios para root..."
    exec sudo -E "$BASH" "$0" "$@"
}

# Executa um comendo como outro utilizador
run_as() {
    [[ "$#" -lt 2 ]] && { warn "run_as(): Precisa de pelo menos 2 parâmetros"; return 1; }
    local user="$1"
    ! id -u "$user" >/dev/null 2>&1 && { warn "run_as(): Utilizador '$user' não existe."; return 1; }
    shift 1
    runuser -u "$user" -- "$@"
}

# Devolve a homedir de $1
get_home() {
    local user="$1" homedir
    [[ -z "$user" ]] && { warn "get_home(): Nenhum utilizador indicado"; return 1; }
    homedir=$(getent passwd "$1" | cut -d: -f6)
    [[ -z "$homedir" ]] && { warn "get_home(): Utilizador não encontrado: $user"; return 1; }
    echo "$homedir"
}

## STRING E TECLADO

# Remover espaços em branco no início e no fim de uma string,
# e também eliminar espaços múltiplos no meio, substituindo-os por um único espaço.
trim() {
    local input="${*:-$(cat -)}"
    printf "%s" "$input" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//; s/[[:space:]]+/ /g';
}

# espera que o utilizador carregue numa tecla
keywait() {
    local msg="${1:-Pressione uma tecla para continuar...}"
    read -rsp "$msg" -n 1 key
    echo ""
}

## FICHEIROS DE CONFIGURAÇÃO

# Verifica se a chave $2 existe no ficheiro $1
config_key_exists() {
    [[ "$#" -ne 2 ]] && { warn "config_key_exists(): Exige 2 parâmetros"; return 1; }
    local file="$1" key="$2" ekey
    [[ ! -r "$file" ]] && return 2
    ekey=$(printf '%s' "$key" | sed 's/[][.^*$\|+?(){}]/\\&/g')
    grep -q -E "^[[:space:]]*${ekey}[[:space:]]*=" "$file"
}

# Obtém o valor da chave $2 no ficheiro $1
get_config_value() {
    local file="$1"
    local key="$2"

    [[ ! -f "$file" ]] && return 1

    # awk explica-se por si mesmo:
    # -F'='      : Usa o sinal de igual como separador
    # -v k="$key": Passa a variável bash para dentro do awk de forma segura
    awk -F'=' -v target="$key" '
    
    # Ignora linhas que começam com # (comentários) ou estão vazias
    /^[[:space:]]*#/ || /^[[:space:]]*$/ { next }

    {
        # Limpa espaços em branco no início e fim da CHAVE (campo $1)
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", $1)

        # Se a chave encontrada for igual à que procuramos
        if ($1 == target) {
            
            # O valor é tudo o que está à direita do primeiro "="
            # Usamos substr para apanhar o resto da linha caso o valor tenha "=" (ex: base64)
            val = substr($0, index($0, "=") + 1)

            # Limpa espaços em branco no início e fim do VALOR
            gsub(/^[[:space:]]+|[[:space:]]+$/, "", val)

            # Opcional: Remove aspas duplas ou simples à volta do valor ("valor" -> valor)
            # Isto é útil para ler configurações do GRUB ou VAR="texto"
            gsub(/^["\047]|["\047]$/, "", val)

            print val
            exit # Encontrou, imprime e sai (para não ler duplicados)
        }
    }' "$file"
}

# Define ou atualiza o valor $3 da chave $2 no ficheiro $1
# Foi o Gemini que fez isto, as regexp são demasiado para mim
set_config_value() {
    local file="$1"
    local key="$2"
    local val="$3"

    [[ -z "$file" || -z "$key" ]] && { echo "Erro: Parâmetros em falta"; return 1; }
    [[ ! -f "$file" ]] && { echo "Erro: Ficheiro não encontrado"; return 1; }

    local tmp_file=$(mktemp)

    awk -v k="$key" -v v="$val" '
    BEGIN { found = 0 }
    {
        # Ignora comentários e linhas vazias (imprime e salta)
        if ($0 ~ /^[[:space:]]*#/ || $0 ~ /^[[:space:]]*$/) {
            print $0
            next
        }

        # Extrai a chave da linha atual para comparar
        # split divide a linha pelo "="
        split($0, parts, "=")
        current_key = parts[1]
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", current_key) # Trim spaces

        if (current_key == k) {
            found = 1
            # === A MAGIA ESTÁ AQUI ===
            # match encontra a posição do texto desde o início até ao primeiro "="
            # RSTART e RLENGTH são variáveis automáticas do awk
            match($0, /^[^=]*=/)
            
            # Capturamos o "prefixo" original. 
            # Se a linha era "key = old", o prefixo é "key = ".
            # Se a linha era "key=old", o prefixo é "key=".
            prefix = substr($0, RSTART, RLENGTH)
            
            # Imprimimos o prefixo original + o novo valor
            print prefix v
        } else {
            # Não é a chave que queremos, imprime a linha original
            print $0
        }
    }
    END {
        # Se não encontrou a chave, adiciona no fim.
        # Usa o formato "key=val" (sem espaços) por ser o mais compatível/seguro.
        if (found == 0) {
            if (NR > 0) print "" # Garante nova linha se o ficheiro não estiver vazio
            print k "=" v
        }
    }
    ' "$file" > "$tmp_file"

    cat "$tmp_file" > "$file"
    rm "$tmp_file"
}


# Deteta se é Debian 12
is_debian12() {
    [[ -f /etc/os-release ]] || return 1
    (
        source /etc/os-release
        [[ "$ID" == "debian" && "$VERSION_ID" == "12" ]]
    )
}

is_debian13() {
    [[ -f /etc/os-release ]] || return 1
    (
        source /etc/os-release
        [[ "$ID" == "debian" && "$VERSION_ID" == "13" ]]
    )
}

## NET

# Testa a ligação ao porto $2 do ip $1
test_port() {
    local ip=$1
    local port=$2
    timeout 2 bash -c "cat < /dev/tcp/$ip/$port" &>/dev/null
}

# Verifica se um hostname é válido (RFC 1123)
is_valid_hostname() {
    local hname="$1"
    
    # Remove o ponto final se existir (tratamento de FQDN)
    hname="${hname%.}"

    # Validações globais: não pode ser vazio nem maior que 253 chars
    [[ -z "$hname" || ${#hname} -gt 253 ]] && return 1

    local label
    local labels
    
    # Divide por pontos
    IFS='.' read -ra labels <<< "$hname"
    
    for label in "${labels[@]}"; do
        # 1. Tamanho do rótulo (1 a 63)
        [[ ${#label} -gt 63 || -z "$label" ]] && return 1
        
        # 2. Conteúdo:
        # - Deve começar por letra ou número ^[a-zA-Z0-9]
        # - Pode ter hífenes no meio [-a-zA-Z0-9]*
        # - Deve terminar por letra ou número [a-zA-Z0-9]$ (se tiver >1 char)
        if [[ ! "$label" =~ ^[a-zA-Z0-9]([-a-zA-Z0-9]*[a-zA-Z0-9])?$ ]]; then
            return 1
        fi
    done
    return 0
}

## FICHEIROS

# Verifica se $1 existe e se existir copia para a dir $2
copy_check() {
    [[ "$#" -ne 2 ]] && { warn "copy_check(): Exige 2 parâmetros"; return 1; }
    local name="$1"
    local dest="$2"
    [[ ! -f "$name" ]] && { warn "copy_check(): Ficheiro $name não encontrado"; return 1; }
    mkdir -p "$dest" || { warn "copy_check(): Erro ao criar $dest"; return 1; }
    cp -a "$name" "$dest" || { warn "copy_check(): Erro ao copiar $name"; return 1; } 
}

# Devolve o tipo de disco onde está montada a diretoria $1
get_disk_type() {
    local target="${1:-.}"
    [[ ! -d "$target" ]] && { echo "Erro: '$target' não existe." >&2; return 1; }
    
    local dev_source
    dev_source=$(df --output=source "$target" 2>/dev/null | tail -n 1)

    [[ "$dev_source" != /dev/* ]] && { echo "VIRTUAL"; return 1; }

    local disk_info
    disk_info=$(lsblk -n -s -o ROTA,NAME "$dev_source" | grep -v "loop" | tail -n 1)

    read -r rota name <<< "$disk_info"

    [[ "$rota" == "1" ]] && { echo "HDD"; return 0; }
    if [[ "$rota" == "0" ]]; then
        if [[ "$name" == *"nvme"* ]]; then
            echo "NVMe"
        else
            echo "SSD"
        fi
        return 0
    fi

    echo "DESCONHECIDO"
    return 1
}

## MEDIA

# Verifica se HDMI está ligado
hdmi_connected() { xrandr | grep "HDMI" | grep -q " connected"; }


# Muda o output de áudio para $1 (nome amigável $2)
change_audio_output() {
    local new_sink="$1"
    local name="$2"
    if [ -n "$new_sink" ]; then
        pactl set-default-sink "$new_sink"
        pactl list short sink-inputs | awk '{print $1}' | while read -r id; do
            pactl move-sink-input "$id" "$new_sink"
        done
        notify-send "Áudio" "Saída: $name" -i audio-volume-high
    fi
}

# Instalar um ficheiro DEB
install_pkg() {
    [[ $# -lt 1 ]] && { error "install_pkg(): É preciso indicar um parâmetro."; return 1; }
    local filename="$1"
    [[ ! -f "$filename" ]] && { error "install_pkg(): Ficheiro não encontrado: $filename"; return 1; }
    [[ "$filename" != /* && "$filename" != ./* ]] && filename="./$filename"
    info_exec "A instalar $filename e dependências" apt_install "$filename"
}

# Remover um pacote deb
remove_pkg() {
    [[ $# -lt 1 ]] && { error "remove_pkg(): É preciso indicar um parâmetro."; return 1; }
    local pkg="$1"
    local status=$(dpkg-query -W -f='${Status}' "$pkg" 2>/dev/null)
    if [[ "$status" == *"ok installed"* ]]; then
        info_exec "A desinstalar '$pkg'" apt_purge "$pkg"
        apt_cmd autoremove >/dev/null 2>&1
    elif [[ "$status" == *"config-files"* ]]; then
        info "A limpar restos de configuração de '$pkg'..."
        apt_purge "$pkg" >/dev/null 2>&1
    else
        warn "Pacote '$pkg' não está instalado (nada a fazer)."
    fi
}


# Faz uma limpeza e correção básica ao sistema
clean_system () {
    info "A iniciar a limpeza do sistema"
    apt_fix
    apt_update
    apt_upgrade
    info "A limpar pacotes obsoletos e cache"
    apt_cmd autoremove --purge
    apt_cmd autoclean
    info "A limpar logs antigos do sistema..."
    journalctl --vacuum-time=2d >/dev/null 2>&1
    # journalctl --vacuum-size=100M >/dev/null 2>&1
    ! command -v bleachbit >/dev/null && { warn "Bleachbit não instalado."; return 0; }
    local users=$(find /home -maxdepth 1 -mindepth 1 -type d -exec basename {} \; | grep -vE 'lost\+found|vagrant|guest|backup')
    [[ -z "$users" ]] && return 0
    local options=(
        "bash.*" "chromium.*" "firefox.*" "gimp.*" "google_chrome.*" "java.*"
        "libreoffice.*" "system.tmp" "system.trash" "system.cache" 
        "thumbnails.*" "vlc.*" "wine.*" "x11.*"
    )
    for U in $users; do
        echo "A limpar lixo do utilizador: $U..."
        run_as "$U" bleachbit --clean "${options[@]}" 2>&1 | grep "recuperado"
    done
}