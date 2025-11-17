#!/bin/bash

# ==========================================================
# ProxMenux - A menu-driven toolkit for Proxmox VE management
# Neo-Morphism Edition with Installation Verification
# ==========================================================
# Author       : MacRimi
# Contributors : cod378
# Version      : 1.5-neomorph
# Last Updated : 17/11/2025
# ==========================================================

# Configuration ============================================
LOCAL_SCRIPTS="/usr/local/share/proxmenux/scripts"
INSTALL_DIR="/usr/local/bin"
BASE_DIR="/usr/local/share/proxmenux"
CONFIG_FILE="$BASE_DIR/config.json"
CACHE_FILE="$BASE_DIR/cache.json"
UTILS_FILE="$BASE_DIR/utils.sh"
LOCAL_VERSION_FILE="$BASE_DIR/version.txt"
MENU_SCRIPT="menu"
VENV_PATH="/opt/googletrans-env"

MONITOR_INSTALL_DIR="$BASE_DIR"
MONITOR_SERVICE_FILE="/etc/systemd/system/proxmenux-monitor.service"
MONITOR_PORT=8008

REPO_URL="https://github.com/MacRimi/ProxMenux.git"
TEMP_DIR="/tmp/proxmenux-install-$$"

# Neo-Morphism Color Palette
NEO_BG="\033[48;5;236m"
NEO_FG="\033[38;5;255m"
NEO_SHADOW="\033[38;5;232m"
NEO_LIGHT="\033[38;5;250m"
NEO_ACCENT="\033[38;5;117m"
NEO_SUCCESS="\033[38;5;157m"
NEO_ERROR="\033[38;5;210m"
NEO_WARN="\033[38;5;222m"
NEO_BORDER="\033[38;5;240m"
RESET="\033[0m"
BOLD="\033[1m"
DIM="\033[2m"

# Legacy colors (keep for compatibility)
YW="\033[33m"
GN="\033[1;92m"
RD="\033[01;31m"
CL="\033[m"
BL="\033[36m"
BFR="\\r\\033[K"

TAB="    "

# Neo-Morphism UI Components ===============================

neo_box_top() {
    local width=${1:-60}
    echo -e "${NEO_BORDER}╭$(printf '─%.0s' $(seq 1 $((width-2))))╮${RESET}"
}

neo_box_bottom() {
    local width=${1:-60}
    echo -e "${NEO_BORDER}╰$(printf '─%.0s' $(seq 1 $((width-2))))╯${RESET}"
}

neo_box_line() {
    local text="$1"
    local width=${2:-60}
    local padding=$((width - ${#text} - 4))
    echo -e "${NEO_BORDER}│${RESET} ${NEO_FG}${text}${RESET}$(printf ' %.0s' $(seq 1 $padding))${NEO_BORDER}│${RESET}"
}

neo_title() {
    local text="$1"
    local width=70
    echo
    neo_box_top $width
    neo_box_line "$(printf '%*s' $(((${#text}+$width-4)/2)) "$text")" $width
    neo_box_bottom $width
    echo
}

neo_spinner() {
    local frames=('◜' '◠' '◝' '◞' '◡' '◟')
    local spin_i=0
    printf "\e[?25l"
    
    while true; do
        printf "\r ${NEO_ACCENT}%s${RESET}" "${frames[spin_i]}"
        spin_i=$(( (spin_i + 1) % ${#frames[@]} ))
        sleep 0.1
    done
}

neo_msg_info() {
    local msg="$1"
    echo -ne "${TAB}${NEO_LIGHT}◆${RESET} ${NEO_FG}${msg}${RESET}"
    neo_spinner &
    SPINNER_PID=$!
}

neo_msg_ok() {
    if [ -n "$SPINNER_PID" ] && ps -p $SPINNER_PID > /dev/null 2>&1; then 
        kill $SPINNER_PID > /dev/null 2>&1
    fi
    printf "\e[?25h"
    local msg="$1"
    echo -e "${BFR}${TAB}${NEO_SUCCESS}✓${RESET} ${NEO_FG}${msg}${RESET}"
}

neo_msg_error() {
    if [ -n "$SPINNER_PID" ] && ps -p $SPINNER_PID > /dev/null 2>&1; then 
        kill $SPINNER_PID > /dev/null 2>&1
    fi
    printf "\e[?25h"
    local msg="$1"
    echo -e "${BFR}${TAB}${NEO_ERROR}✗${RESET} ${NEO_ERROR}${msg}${RESET}"
}

neo_msg_warn() {
    if [ -n "$SPINNER_PID" ] && ps -p $SPINNER_PID > /dev/null 2>&1; then 
        kill $SPINNER_PID > /dev/null 2>&1
    fi
    printf "\e[?25h"
    local msg="$1"
    echo -e "${BFR}${TAB}${NEO_WARN}⚠${RESET} ${NEO_WARN}${msg}${RESET}"
}

neo_progress_bar() {
    local current=$1
    local total=$2
    local width=50
    local percent=$((current * 100 / total))
    local filled=$((width * current / total))
    local empty=$((width - filled))
    
    printf "\r${TAB}${NEO_BORDER}["
    printf "${NEO_ACCENT}%${filled}s" | tr ' ' '█'
    printf "${NEO_SHADOW}%${empty}s" | tr ' ' '░'
    printf "${NEO_BORDER}]${RESET} ${NEO_FG}%3d%%${RESET}" "$percent"
}

show_neo_logo() {
    clear
    echo
    echo -e "${TAB}${NEO_ACCENT}${BOLD}"
    echo -e "${TAB}  ╔═══════════════════════════════════════╗"
    echo -e "${TAB}  ║                                       ║"
    echo -e "${TAB}  ║         ${NEO_FG}ProxMenux${NEO_ACCENT}                   ║"
    echo -e "${TAB}  ║                                       ║"
    echo -e "${TAB}  ║    ${DIM}${NEO_LIGHT}An Interactive Menu System${NEO_ACCENT}${BOLD}     ║"
    echo -e "${TAB}  ║    ${DIM}${NEO_LIGHT}for Proxmox VE Management${NEO_ACCENT}${BOLD}      ║"
    echo -e "${TAB}  ║                                       ║"
    echo -e "${TAB}  ╚═══════════════════════════════════════╝${RESET}"
    echo
}

# Installation Verification System =========================

verify_component() {
    local component="$1"
    local check_type="$2"
    
    case "$component" in
        "dialog")
            if command -v dialog > /dev/null 2>&1; then
                return 0
            fi
            ;;
        "curl")
            if command -v curl > /dev/null 2>&1; then
                return 0
            fi
            ;;
        "jq")
            if command -v jq > /dev/null 2>&1 && jq --version > /dev/null 2>&1; then
                return 0
            fi
            ;;
        "python3")
            if command -v python3 > /dev/null 2>&1; then
                return 0
            fi
            ;;
        "venv")
            if [ -d "$VENV_PATH" ] && [ -f "$VENV_PATH/bin/activate" ]; then
                if source "$VENV_PATH/bin/activate" 2>/dev/null; then
                    deactivate
                    return 0
                fi
            fi
            ;;
        "googletrans")
            if [ -f "$VENV_PATH/bin/activate" ]; then
                source "$VENV_PATH/bin/activate"
                if python3 -c "import googletrans" 2>/dev/null; then
                    deactivate
                    return 0
                fi
                deactivate
            fi
            ;;
        "menu_script")
            if [ -f "$INSTALL_DIR/$MENU_SCRIPT" ] && [ -x "$INSTALL_DIR/$MENU_SCRIPT" ]; then
                return 0
            fi
            ;;
        "config")
            if [ -f "$CONFIG_FILE" ] && jq empty "$CONFIG_FILE" 2>/dev/null; then
                return 0
            fi
            ;;
        "scripts")
            if [ -d "$BASE_DIR/scripts" ] && [ -f "$UTILS_FILE" ] && [ -x "$UTILS_FILE" ]; then
                return 0
            fi
            ;;
        "monitor")
            if [ -f "$MONITOR_INSTALL_DIR/ProxMenux-Monitor.AppImage" ] && \
               [ -f "$MONITOR_SERVICE_FILE" ] && \
               systemctl is-enabled proxmenux-monitor.service > /dev/null 2>&1; then
                return 0
            fi
            ;;
    esac
    
    return 1
}

run_installation_diagnostics() {
    local install_type="$1"
    local issues=()
    local corrupted=false
    
    neo_title "Running Installation Diagnostics"
    
    echo -e "${TAB}${NEO_FG}Checking core components...${RESET}\n"
    
    # Check basic dependencies
    local basic_components=("dialog" "curl" "jq")
    for comp in "${basic_components[@]}"; do
        neo_msg_info "Verifying $comp..."
        sleep 0.3
        if verify_component "$comp"; then
            neo_msg_ok "$comp is properly installed"
        else
            neo_msg_error "$comp is missing or corrupted"
            issues+=("$comp")
            corrupted=true
        fi
    done
    
    # Check menu script
    neo_msg_info "Verifying menu script..."
    sleep 0.3
    if verify_component "menu_script"; then
        neo_msg_ok "Menu script is properly installed"
    else
        neo_msg_error "Menu script is missing or not executable"
        issues+=("menu_script")
        corrupted=true
    fi
    
    # Check configuration
    neo_msg_info "Verifying configuration files..."
    sleep 0.3
    if verify_component "config"; then
        neo_msg_ok "Configuration is valid"
    else
        neo_msg_warn "Configuration is missing or corrupted (will be recreated)"
        issues+=("config")
    fi
    
    # Check scripts directory
    neo_msg_info "Verifying scripts directory..."
    sleep 0.3
    if verify_component "scripts"; then
        neo_msg_ok "Scripts directory is properly installed"
    else
        neo_msg_error "Scripts directory is missing or corrupted"
        issues+=("scripts")
        corrupted=true
    fi
    
    # Check translation components if needed
    if [ "$install_type" = "translation" ] || [ "$install_type" = "2" ]; then
        echo -e "\n${TAB}${NEO_FG}Checking translation components...${RESET}\n"
        
        neo_msg_info "Verifying Python3..."
        sleep 0.3
        if verify_component "python3"; then
            neo_msg_ok "Python3 is properly installed"
        else
            neo_msg_error "Python3 is missing"
            issues+=("python3")
            corrupted=true
        fi
        
        neo_msg_info "Verifying virtual environment..."
        sleep 0.3
        if verify_component "venv"; then
            neo_msg_ok "Virtual environment is properly configured"
        else
            neo_msg_error "Virtual environment is missing or corrupted"
            issues+=("venv")
            corrupted=true
        fi
        
        neo_msg_info "Verifying googletrans..."
        sleep 0.3
        if verify_component "googletrans"; then
            neo_msg_ok "Googletrans is properly installed"
        else
            neo_msg_error "Googletrans is missing or corrupted"
            issues+=("googletrans")
            corrupted=true
        fi
    fi
    
    # Check monitor
    echo -e "\n${TAB}${NEO_FG}Checking ProxMenux Monitor...${RESET}\n"
    neo_msg_info "Verifying monitor installation..."
    sleep 0.3
    if verify_component "monitor"; then
        neo_msg_ok "ProxMenux Monitor is properly installed"
    else
        neo_msg_warn "ProxMenux Monitor needs installation/repair"
        issues+=("monitor")
    fi
    
    echo
    
    if [ ${#issues[@]} -eq 0 ]; then
        neo_title "✓ All Components Verified Successfully"
        return 0
    else
        neo_title "⚠ Issues Detected: ${#issues[@]} component(s)"
        echo -e "${TAB}${NEO_WARN}The following components need attention:${RESET}\n"
        for issue in "${issues[@]}"; do
            echo -e "${TAB}  ${NEO_ERROR}•${RESET} ${NEO_FG}${issue}${RESET}"
        done
        echo
        
        if [ "$corrupted" = true ]; then
            if whiptail --title "Installation Repair Required" \
                --yesno "Critical components are missing or corrupted.\n\nDo you want to repair the installation now?" 12 60; then
                return 2  # Needs repair
            else
                return 1  # User declined repair
            fi
        else
            return 3  # Minor issues only
        fi
    fi
}

# Cleanup and utility functions ============================

cleanup_corrupted_files() {
    if [ -f "$CONFIG_FILE" ] && ! jq empty "$CONFIG_FILE" >/dev/null 2>&1; then
        neo_msg_warn "Cleaning up corrupted configuration file..."
        rm -f "$CONFIG_FILE"
    fi
    if [ -f "$CACHE_FILE" ] && ! jq empty "$CACHE_FILE" >/dev/null 2>&1; then
        neo_msg_warn "Cleaning up corrupted cache file..."
        rm -f "$CACHE_FILE"
    fi
}

cleanup() {
    if [ -d "$TEMP_DIR" ]; then
        rm -rf "$TEMP_DIR"
    fi
}

trap cleanup EXIT

update_config() {
    local component="$1"
    local status="$2"
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    
    local tracked_components=("dialog" "curl" "jq" "python3" "python3-venv" "python3-pip" "virtual_environment" "pip" "googletrans" "proxmenux_monitor")
    
    if [[ " ${tracked_components[@]} " =~ " ${component} " ]]; then
        mkdir -p "$(dirname "$CONFIG_FILE")"
        
        if [ ! -f "$CONFIG_FILE" ] || ! jq empty "$CONFIG_FILE" >/dev/null 2>&1; then
            echo '{}' > "$CONFIG_FILE"
        fi
        
        local tmp_file=$(mktemp)
        if jq --arg comp "$component" --arg stat "$status" --arg time "$timestamp" \
           '.[$comp] = {status: $stat, timestamp: $time}' "$CONFIG_FILE" > "$tmp_file" 2>/dev/null; then
            mv "$tmp_file" "$CONFIG_FILE"
        else
            echo '{}' > "$CONFIG_FILE"
            jq --arg comp "$component" --arg stat "$status" --arg time "$timestamp" \
               '.[$comp] = {status: $stat, timestamp: $time}' "$CONFIG_FILE" > "$tmp_file" && mv "$tmp_file" "$CONFIG_FILE"
        fi
        
        [ -f "$tmp_file" ] && rm -f "$tmp_file"
    fi
}

check_existing_installation() {
    local has_venv=false
    local has_config=false
    local has_language=false
    local has_menu=false
    
    if [ -f "$INSTALL_DIR/$MENU_SCRIPT" ]; then
        has_menu=true
    fi
    
    if [ -d "$VENV_PATH" ] && [ -f "$VENV_PATH/bin/activate" ]; then
        has_venv=true
    fi
    
    if [ -f "$CONFIG_FILE" ]; then
        if jq empty "$CONFIG_FILE" >/dev/null 2>&1; then
            has_config=true
            local current_language=$(jq -r '.language // empty' "$CONFIG_FILE" 2>/dev/null)
            if [[ -n "$current_language" && "$current_language" != "null" && "$current_language" != "empty" ]]; then
                has_language=true
            fi
        else
            rm -f "$CONFIG_FILE"
        fi
    fi
    
    if [ "$has_venv" = true ] && [ "$has_language" = true ]; then
        echo "translation"
    elif [ "$has_menu" = true ] && [ "$has_venv" = false ]; then
        echo "normal"
    elif [ "$has_menu" = true ]; then
        echo "unknown"
    else
        echo "none"
    fi
}

# Installation functions ===================================

select_language() {
    if [ -f "$CONFIG_FILE" ] && jq empty "$CONFIG_FILE" >/dev/null 2>&1; then
        local existing_language=$(jq -r '.language // empty' "$CONFIG_FILE" 2>/dev/null)
        if [[ -n "$existing_language" && "$existing_language" != "null" && "$existing_language" != "empty" ]]; then
            LANGUAGE="$existing_language"
            neo_msg_ok "Using existing language configuration: $LANGUAGE"
            return 0
        fi
    fi
    
    LANGUAGE=$(whiptail --title "Select Language" --menu "Choose a language for the menu:" 20 60 12 \
        "en" "English (Recommended)" \
        "es" "Spanish" \
        "fr" "French" \
        "de" "German" \
        "it" "Italian" \
        "pt" "Portuguese" 3>&1 1>&2 2>&3)
    
    if [ -z "$LANGUAGE" ]; then
        neo_msg_error "No language selected. Exiting."
        exit 1
    fi
    
    mkdir -p "$(dirname "$CONFIG_FILE")"
    
    if [ ! -f "$CONFIG_FILE" ] || ! jq empty "$CONFIG_FILE" >/dev/null 2>&1; then
        echo '{}' > "$CONFIG_FILE"
    fi
    
    local tmp_file=$(mktemp)
    if jq --arg lang "$LANGUAGE" '. + {language: $lang}' "$CONFIG_FILE" > "$tmp_file" 2>/dev/null; then
        mv "$tmp_file" "$CONFIG_FILE"
    else
        echo "{\"language\": \"$LANGUAGE\"}" > "$CONFIG_FILE"
    fi
    
    [ -f "$tmp_file" ] && rm -f "$tmp_file"
    
    neo_msg_ok "Language set to: $LANGUAGE"
}

install_normal_version() {
    local total_steps=5
    
    neo_title "Installing ProxMenux - Normal Version"
    
    # Step 1: Dependencies
    echo -e "${TAB}${NEO_FG}Step 1/${total_steps}: Installing dependencies${RESET}\n"
    neo_progress_bar 1 $total_steps
    echo
    
    if ! command -v jq > /dev/null 2>&1; then
        neo_msg_info "Installing jq..."
        apt-get update > /dev/null 2>&1
        
        if apt-get install -y jq > /dev/null 2>&1 && command -v jq > /dev/null 2>&1; then
            neo_msg_ok "jq installed successfully"
            update_config "jq" "installed"
        else
            local jq_url="https://github.com/jqlang/jq/releases/download/jq-1.7.1/jq-linux-amd64"
            if wget -q -O /usr/local/bin/jq "$jq_url" 2>/dev/null && chmod +x /usr/local/bin/jq; then
                neo_msg_ok "jq installed from GitHub"
                update_config "jq" "installed_from_github"
            else
                neo_msg_error "Failed to install jq"
                update_config "jq" "failed"
                return 1
            fi
        fi
    else
        neo_msg_ok "jq already installed"
        update_config "jq" "already_installed"
    fi
    
    BASIC_DEPS=("dialog" "curl" "git")
    for pkg in "${BASIC_DEPS[@]}"; do
        if ! dpkg -l | grep -qw "$pkg"; then
            neo_msg_info "Installing $pkg..."
            if apt-get install -y "$pkg" > /dev/null 2>&1; then
                neo_msg_ok "$pkg installed successfully"
                update_config "$pkg" "installed"
            else
                neo_msg_error "Failed to install $pkg"
                update_config "$pkg" "failed"
                return 1
            fi
        else
            neo_msg_ok "$pkg already installed"
            update_config "$pkg" "already_installed"
        fi
    done
    
    # Step 2: Clone repository
    echo -e "\n${TAB}${NEO_FG}Step 2/${total_steps}: Cloning repository${RESET}\n"
    neo_progress_bar 2 $total_steps
    echo
    
    neo_msg_info "Downloading ProxMenux..."
    if ! git clone --depth 1 "$REPO_URL" "$TEMP_DIR" 2>/dev/null; then
        neo_msg_error "Failed to clone repository"
        return 1
    fi
    neo_msg_ok "Repository cloned successfully"
    
    cd "$TEMP_DIR"
    
    # Step 3: Create directories
    echo -e "\n${TAB}${NEO_FG}Step 3/${total_steps}: Creating directories${RESET}\n"
    neo_progress_bar 3 $total_steps
    echo
    
    mkdir -p "$BASE_DIR"
    mkdir -p "$INSTALL_DIR"
    
    if [ ! -f "$CONFIG_FILE" ]; then
        echo '{}' > "$CONFIG_FILE"
    fi
    
    neo_msg_ok "Directories created successfully"
    
    # Step 4: Copy files
    echo -e "\n${TAB}${NEO_FG}Step 4/${total_steps}: Installing files${RESET}\n"
    neo_progress_bar 4 $total_steps
    echo
    
    neo_msg_info "Copying system files..."
    cp "./scripts/utils.sh" "$UTILS_FILE"
    cp "./menu" "$INSTALL_DIR/$MENU_SCRIPT"
    cp "./version.txt" "$LOCAL_VERSION_FILE"
    cp "./install_proxmenux.sh" "$BASE_DIR/install_proxmenux.sh"
    
    mkdir -p "$BASE_DIR/scripts"
    cp -r "./scripts/"* "$BASE_DIR/scripts/"
    chmod -R +x "$BASE_DIR/scripts/"
    chmod +x "$BASE_DIR/install_proxmenux.sh"
    chmod +x "$INSTALL_DIR/$MENU_SCRIPT"
    
    neo_msg_ok "Files installed successfully"
    
    # Step 5: Install monitor
    echo -e "\n${TAB}${NEO_FG}Step 5/${total_steps}: Installing ProxMenux Monitor${RESET}\n"
    neo_progress_bar 5 $total_steps
    echo
    
    install_proxmenux_monitor
    local monitor_status=$?
    
    if [ $monitor_status -eq 0 ]; then
        create_monitor_service
    fi
    
    echo
    neo_title "✓ Installation Complete"
}

install_translation_version() {
    local total_steps=6
    
    neo_title "Installing ProxMenux - Translation Version"
    
    # Step 1: Language selection
    echo -e "${TAB}${NEO_FG}Step 1/${total_steps}: Language configuration${RESET}\n"
    neo_progress_bar 1 $total_steps
    echo
    select_language
    
    # Step 2: Dependencies
    echo -e "\n${TAB}${NEO_FG}Step 2/${total_steps}: Installing dependencies${RESET}\n"
    neo_progress_bar 2 $total_steps
    echo
    
    if ! command -v jq > /dev/null 2>&1; then
        neo_msg_info "Installing jq..."
        apt-get update > /dev/null 2>&1
        
        if apt-get install -y jq > /dev/null 2>&1; then
            neo_msg_ok "jq installed successfully"
            update_config "jq" "installed"
        else
            local jq_url="https://github.com/jqlang/jq/releases/download/jq-1.7.1/jq-linux-amd64"
            if wget -q -O /usr/local/bin/jq "$jq_url" 2>/dev/null && chmod +x /usr/local/bin/jq; then
                neo_msg_ok "jq installed from GitHub"
                update_config "jq" "installed_from_github"
            else
                neo_msg_error "Failed to install jq"
                return 1
            fi
        fi
    else
        neo_msg_ok "jq already installed"
    fi
    
    DEPS=("dialog" "curl" "git" "python3" "python3-venv" "python3-pip")
    for pkg in "${DEPS[@]}"; do
        if ! dpkg -l | grep -qw "$pkg"; then
            neo_msg_info "Installing $pkg..."
            if apt-get install -y "$pkg" > /dev/null 2>&1; then
                neo_msg_ok "$pkg installed successfully"
                update_config "$pkg" "installed"
            else
                neo_msg_error "Failed to install $pkg"
                return 1
            fi
        else
            neo_msg_ok "$pkg already installed"
        fi
    done
    
    # Step 3: Translation environment
    echo -e "\n${TAB}${NEO_FG}Step 3/${total_steps}: Setting up translation environment${RESET}\n"
    neo_progress_bar 3 $total_steps
    echo
    
    if [ ! -d "$VENV_PATH" ] || [ ! -f "$VENV_PATH/bin/activate" ]; then
        neo_msg_info "Creating virtual environment..."
        python3 -m venv --system-site-packages "$VENV_PATH" > /dev/null 2>&1
        if [ ! -f "$VENV_PATH/bin/activate" ]; then
            neo_msg_error "Failed to create virtual environment"
            return 1
        fi
        neo_msg_ok "Virtual environment created"
        update_config "virtual_environment" "created"
    else
        neo_msg_ok "Virtual environment already exists"
    fi
    
    source "$VENV_PATH/bin/activate"
    
    neo_msg_info "Upgrading pip..."
    if pip install --upgrade pip > /dev/null 2>&1; then
        neo_msg_ok "pip upgraded successfully"
        update_config "pip" "upgraded"
    fi
    
    neo_msg_info "Installing googletrans..."
    if pip install --break-system-packages --no-cache-dir googletrans==4.0.0-rc1 > /dev/null 2>&1; then
        neo_msg_ok "googletrans installed successfully"
        update_config "googletrans" "installed"
    else
        neo_msg_error "Failed to install googletrans"
        deactivate
        return 1
    fi
    
    deactivate
    
    # Step 4: Clone repository
    echo -e "\n${TAB}${NEO_FG}Step 4/${total_steps}: Cloning repository${RESET}\n"
    neo_progress_bar 4 $total_steps
    echo
    
    neo_msg_info "Downloading ProxMenux..."
    if ! git clone --depth 1 "$REPO_URL" "$TEMP_DIR" 2>/dev/null; then
        neo_msg_error "Failed to clone repository"
        return 1
    fi
    neo_msg_ok "Repository cloned successfully"
    
    cd "$TEMP_DIR"
    
    # Step 5: Copy files
    echo -e "\n${TAB}${NEO_FG}Step 5/${total_steps}: Installing files${RESET}\n"
    neo_progress_bar 5 $total_steps
    echo
    
    mkdir -p "$BASE_DIR"
    mkdir -p "$INSTALL_DIR"
    
    neo_msg_info "Copying system files..."
    cp "./json/cache.json" "$CACHE_FILE"
    cp "./scripts/utils.sh" "$UTILS_FILE"
    cp "./menu" "$INSTALL_DIR/$MENU_SCRIPT"
    cp "./version.txt" "$LOCAL_VERSION_FILE"
    cp "./install_proxmenux.sh" "$BASE_DIR/install_proxmenux.sh"
    
    mkdir -p "$BASE_DIR/scripts"
    cp -r "./scripts/"* "$BASE_DIR/scripts/"
    chmod -R +x "$BASE_DIR/scripts/"
    chmod +x "$BASE_DIR/install_proxmenux.sh"
    chmod +x "$INSTALL_DIR/$MENU_SCRIPT"
    
    neo_msg_ok "Files installed successfully"
    
    # Step 6: Install monitor
    echo -e "\n${TAB}${NEO_FG}Step 6/${total_steps}: Installing ProxMenux Monitor${RESET}\n"
    neo_progress_bar 6 $total_steps
    echo
    
    install_proxmenux_monitor
    local monitor_status=$?
    
    if [ $monitor_status -eq 0 ]; then
        create_monitor_service
    fi
    
    echo
    neo_title "✓ Installation Complete"
}

# Monitor functions (keeping original logic) ==============

get_server_ip() {
    local ip
    ip=$(ip route get 1.1.1.1 2>/dev/null | grep -oP 'src \K\S+')
    
    if [ -z "$ip" ]; then
        ip=$(hostname -I | awk '{print $1}')
    fi
    
    if [ -z "$ip" ]; then
        ip="localhost"
    fi
    
    echo "$ip"
}

detect_latest_appimage() {
    local appimage_dir="$TEMP_DIR/AppImage"
    
    if [ ! -d "$appimage_dir" ]; then
        return 1
    fi
    
    local latest_appimage=$(find "$appimage_dir" -name "ProxMenux-*.AppImage" -type f | sort -V | tail -1)
    
    if [ -z "$latest_appimage" ]; then
        return 1
    fi
    
    echo "$latest_appimage"
    return 0
}

get_appimage_version() {
    local appimage_path="$1"
    local filename=$(basename "$appimage_path")
    local version=$(echo "$filename" | grep -oP 'ProxMenux-\K[0-9]+\.[0-9]+\.[0-9]+')
    echo "$version"
}

install_proxmenux_monitor() {
    local appimage_source=$(detect_latest_appimage)
    
    if [ -z "$appimage_source" ] || [ ! -f "$appimage_source" ]; then
        neo_msg_warn "ProxMenux Monitor AppImage not found"
        update_config "proxmenux_monitor" "appimage_not_found"
        return 1
    fi
    
    local appimage_version=$(get_appimage_version "$appimage_source")
    
    if systemctl is-active --quiet proxmenux-monitor.service; then
        systemctl stop proxmenux-monitor.service
    fi
    
    local service_exists=false
    if [ -f "$MONITOR_SERVICE_FILE" ]; then
        service_exists=true
    fi
    
    local sha256_file="$TEMP_DIR/AppImage/ProxMenux-Monitor.AppImage.sha256"
    
    if [ -f "$sha256_file" ]; then
        neo_msg_info "Verifying AppImage integrity..."
        local expected_hash=$(cat "$sha256_file" | grep -Eo '^[a-f0-9]+' | tr -d '\n')
        local actual_hash=$(sha256sum "$appimage_source" | awk '{print $1}')
        
        if [ "$expected_hash" != "$actual_hash" ]; then
            neo_msg_error "SHA256 verification failed!"
            return 1
        fi
        neo_msg_ok "SHA256 verification passed"
    fi
    
    neo_msg_info "Installing ProxMenux Monitor v$appimage_version..."
    mkdir -p "$MONITOR_INSTALL_DIR"
    
    local target_path="$MONITOR_INSTALL_DIR/ProxMenux-Monitor.AppImage"
    cp "$appimage_source" "$target_path"
    chmod +x "$target_path"
    
    neo_msg_ok "ProxMenux Monitor v$appimage_version installed"
    
    if [ "$service_exists" = false ]; then
        return 0
    else
        systemctl start proxmenux-monitor.service
        sleep 2
        
        if systemctl is-active --quiet proxmenux-monitor.service; then
            update_config "proxmenux_monitor" "updated"
            return 2
        else
            neo_msg_warn "Service failed to restart"
            update_config "proxmenux_monitor" "failed"
            return 1
        fi
    fi
}

create_monitor_service() {
    neo_msg_info "Creating ProxMenux Monitor service..."
    
    local exec_path="$MONITOR_INSTALL_DIR/ProxMenux-Monitor.AppImage"
    
    if [ -f "$TEMP_DIR/systemd/proxmenux-monitor.service" ]; then
        sed "s|ExecStart=.*|ExecStart=$exec_path|g" \
            "$TEMP_DIR/systemd/proxmenux-monitor.service" > "$MONITOR_SERVICE_FILE"
        neo_msg_ok "Using service file from repository"
    else
        cat > "$MONITOR_SERVICE_FILE" << EOF
[Unit]
Description=ProxMenux Monitor - Web Dashboard
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=$MONITOR_INSTALL_DIR
ExecStart=$exec_path
Restart=on-failure
RestartSec=10
Environment="PORT=$MONITOR_PORT"

[Install]
WantedBy=multi-user.target
EOF
        neo_msg_ok "Created default service file"
    fi

    systemctl daemon-reload
    systemctl enable proxmenux-monitor.service > /dev/null 2>&1
    systemctl start proxmenux-monitor.service > /dev/null 2>&1
    
    sleep 3
    
    if systemctl is-active --quiet proxmenux-monitor.service; then
        neo_msg_ok "ProxMenux Monitor service started successfully"
        update_config "proxmenux_monitor" "installed"
        return 0
    else
        neo_msg_warn "ProxMenux Monitor service failed to start"
        neo_msg_warn "Check logs: journalctl -u proxmenux-monitor -n 20"
        update_config "proxmenux_monitor" "failed"
        return 1
    fi
}

uninstall_proxmenux() {
    local install_type="$1"
    local force_clean="$2"
    
    if [ "$force_clean" != "force" ]; then
        if ! whiptail --title "Uninstall ProxMenux" --yesno "Are you sure you want to uninstall ProxMenux?" 10 60; then
            return 1
        fi
    fi
    
    neo_title "Uninstalling ProxMenux"
    
    if systemctl is-active --quiet proxmenux-monitor.service; then
        neo_msg_info "Stopping ProxMenux Monitor service..."
        systemctl stop proxmenux-monitor.service
        neo_msg_ok "Service stopped"
    fi
    
    if systemctl is-enabled --quiet proxmenux-monitor.service 2>/dev/null; then
        neo_msg_info "Disabling ProxMenux Monitor service..."
        systemctl disable proxmenux-monitor.service
        neo_msg_ok "Service disabled"
    fi
    
    if [ -f "$MONITOR_SERVICE_FILE" ]; then
        neo_msg_info "Removing ProxMenux Monitor service..."
        rm -f "$MONITOR_SERVICE_FILE"
        systemctl daemon-reload
        neo_msg_ok "Service removed"
    fi
    
    if [ -d "$MONITOR_INSTALL_DIR" ]; then
        neo_msg_info "Removing ProxMenux Monitor directory..."
        rm -rf "$MONITOR_INSTALL_DIR"
        neo_msg_ok "Directory removed"
    fi
    
    if [ -f "$VENV_PATH/bin/activate" ]; then
        neo_msg_info "Removing virtual environment..."
        source "$VENV_PATH/bin/activate"
        pip uninstall -y googletrans >/dev/null 2>&1
        deactivate
        rm -rf "$VENV_PATH"
        neo_msg_ok "Virtual environment removed"
    fi
    
    if [ "$install_type" = "translation" ] && [ "$force_clean" != "force" ]; then
        DEPS_TO_REMOVE=$(whiptail --title "Remove Translation Dependencies" --checklist \
            "Select translation-specific dependencies to remove:" 15 60 3 \
            "python3-venv" "Python virtual environment" OFF \
            "python3-pip" "Python package installer" OFF \
            "python3" "Python interpreter" OFF \
            3>&1 1>&2 2>&3)
        
        if [ -n "$DEPS_TO_REMOVE" ]; then
            neo_msg_info "Removing selected dependencies..."
            read -r -a DEPS_ARRAY <<< "$(echo "$DEPS_TO_REMOVE" | tr -d '"')"
            for dep in "${DEPS_ARRAY[@]}"; do
                apt-mark auto "$dep" >/dev/null 2>&1
                apt-get -y --purge autoremove "$dep" >/dev/null 2>&1
            done
            apt-get autoremove -y --purge >/dev/null 2>&1
            neo_msg_ok "Dependencies removed"
        fi
    fi
    
    neo_msg_info "Removing core files..."
    rm -f "$INSTALL_DIR/$MENU_SCRIPT"
    rm -rf "$BASE_DIR"
    neo_msg_ok "Core files removed"
    
    [ -f /root/.bashrc.bak ] && mv /root/.bashrc.bak /root/.bashrc
    if [ -f /etc/motd.bak ]; then
        mv /etc/motd.bak /etc/motd
    else
        sed -i '/This system is optimised by: ProxMenux/d' /etc/motd
    fi
    
    echo
    neo_title "✓ ProxMenux Uninstalled Successfully"
    return 0
}

handle_installation_change() {
    local current_type="$1"
    local new_type="$2"
    
    if [ "$current_type" = "$new_type" ]; then
        return 0
    fi
    
    case "$current_type-$new_type" in
        "translation-1"|"translation-normal")
            if whiptail --title "Installation Type Change" \
                --yesno "Switch from Translation to Normal Version?\n\nThis will remove translation components." 10 60; then
                neo_msg_info "Preparing for installation type change..."
                uninstall_proxmenux "translation" "force" >/dev/null 2>&1
                return 0
            else
                return 1
            fi
            ;;
        "normal-2"|"normal-translation")
            if whiptail --title "Installation Type Change" \
                --yesno "Switch from Normal to Translation Version?\n\nThis will add translation components." 10 60; then
                return 0
            else
                return 1
            fi
            ;;
        *)
            return 0
            ;;
    esac
}

show_installation_confirmation() {
    local install_type="$1"
    
    case "$install_type" in
        "1")
            if whiptail --title "ProxMenux - Normal Version Installation" \
                --yesno "ProxMenux Normal Version will install:\n\n• dialog  (interactive menus) - Official Debian package\n• curl       (file downloads) - Official Debian package\n• jq        (JSON processing) - Official Debian package\n• ProxMenux core files     (/usr/local/share/proxmenux)\n• ProxMenux Monitor        (Web dashboard on port 8008)\n\nThis is a lightweight installation with minimal dependencies.\n\nProceed with installation?" 20 70; then
                return 0
            else
                return 1
            fi
            ;;
        "2")
            if whiptail --title "ProxMenux - Translation Version Installation" \
                --yesno "ProxMenux Translation Version will install:\n\n• dialog (interactive menus)\n• curl (file downloads)\n• jq (JSON processing)\n• python3 + python3-venv + python3-pip\n• Google Translate library (googletrans)\n• Virtual environment (/opt/googletrans-env)\n• Translation cache system\n• ProxMenux core files\n• ProxMenux Monitor        (Web dashboard on port 8008)\n\nThis version requires more dependencies for translation support.\n\nProceed with installation?" 20 70; then
                return 0
            else
                return 1
            fi
            ;;
    esac
}

show_installation_options() {
    local current_install_type
    current_install_type=$(check_existing_installation)
    local pve_version
    pve_version=$(pveversion 2>/dev/null | grep -oP 'pve-manager/\K[0-9]+' | head -1)
    
    local menu_title="ProxMenux Installation"
    local menu_text="Choose installation type:"
    
    if [ "$current_install_type" != "none" ]; then
        case "$current_install_type" in
            "translation")
                menu_title="ProxMenux Update - Translation Version Detected"
                ;;
            "normal")
                menu_title="ProxMenux Update - Normal Version Detected"
                ;;
            "unknown")
                menu_title="ProxMenux Update - Existing Installation Detected"
                ;;
        esac
    fi
    
    if [[ "$pve_version" -ge 9 ]]; then
        INSTALL_TYPE=$(whiptail --backtitle "ProxMenux Neo-Morphism Edition" --title "$menu_title" --menu "\n$menu_text" 14 70 2 \
            "1" "Normal Version      (English only)" 3>&1 1>&2 2>&3)
    else
        INSTALL_TYPE=$(whiptail --backtitle "ProxMenux Neo-Morphism Edition" --title "$menu_title" --menu "\n$menu_text" 14 70 2 \
            "1" "Normal Version      (English only)" \
            "2" "Translation Version (Multi-language support)" 3>&1 1>&2 2>&3)
    fi
    
    if [ -z "$INSTALL_TYPE" ]; then
        show_neo_logo
        neo_msg_warn "Installation cancelled"
        exit 1
    fi
    
    if [ "$current_install_type" = "none" ]; then
        if ! show_installation_confirmation "$INSTALL_TYPE"; then
            show_neo_logo
            neo_msg_warn "Installation cancelled"
            exit 1
        fi
    fi
    
    if ! handle_installation_change "$current_install_type" "$INSTALL_TYPE"; then
        show_neo_logo
        neo_msg_warn "Installation cancelled"
        exit 1
    fi
}

# Main installation function ===============================

install_proxmenux() {
    local current_install_type
    current_install_type=$(check_existing_installation)
    
    # Run diagnostics if installation exists
    if [ "$current_install_type" != "none" ]; then
        run_installation_diagnostics "$current_install_type"
        local diag_result=$?
        
        case $diag_result in
            0)
                # All good - proceed with update
                ;;
            1)
                # User declined repair
                show_neo_logo
                neo_msg_warn "Installation check cancelled"
                exit 0
                ;;
            2)
                # Critical repair needed - force reinstall
                neo_msg_warn "Critical issues detected - forcing reinstall..."
                uninstall_proxmenux "$current_install_type" "force" >/dev/null 2>&1
                ;;
            3)
                # Minor issues - continue anyway
                neo_msg_warn "Minor issues detected but continuing..."
                ;;
        esac
    fi
    
    show_installation_options
    
    case "$INSTALL_TYPE" in
        "1")
            show_neo_logo
            install_normal_version
            ;;
        "2")
            show_neo_logo
            install_translation_version
            ;;
        *)
            neo_msg_error "Invalid option selected"
            exit 1
            ;;
    esac

    if [[ -f "$UTILS_FILE" ]]; then
        source "$UTILS_FILE"
    fi
    
    # Final verification
    echo
    neo_title "Running Post-Installation Verification"
    
    run_installation_diagnostics "$INSTALL_TYPE"
    local final_check=$?
    
    if [ $final_check -eq 0 ]; then
        echo
        neo_title "✓ ProxMenux Successfully Installed"
        
        if systemctl is-active --quiet proxmenux-monitor.service; then
            local server_ip=$(get_server_ip)
            echo -e "${TAB}${NEO_ACCENT}🌐  ProxMenux Monitor:${RESET} ${NEO_FG}http://${server_ip}:${MONITOR_PORT}${RESET}"
            echo
        fi
        
        echo -e "${TAB}${NEO_FG}To launch ProxMenux, run:${RESET}"
        echo -e "${TAB}${NEO_ACCENT}${BOLD}    menu${RESET}"
        echo
    else
        echo
        neo_msg_warn "Installation completed with warnings"
        neo_msg_warn "Please review the diagnostic results above"
        echo
    fi
    
    exit 0
}

# Entry point ==============================================

if [ "$(id -u)" -ne 0 ]; then
    echo -e "${NEO_ERROR}This script must be run as root.${RESET}"
    exit 1
fi

show_neo_logo
cleanup_corrupted_files
install_proxmenux
