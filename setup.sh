#!/usr/bin/env bash
set -euo pipefail

# Colors and formatting
bold=$(tput bold)
normal=$(tput sgr0)
GREEN='\033[32;1m'
RED='\033[31;1m'
YELLOW='\033[33;1m'
CYAN='\033[36;1m'
RESET='\033[0m'

# Check root
if [[ $EUID -ne 0 ]]; then
    printf "${RED}${bold}This script must be run as root.${RESET}\n"
    exit 1
fi

# Set theme source directory
THEME_DIR=$(dirname "$(realpath "$0")")

# Available resolutions
RESOLUTIONS=(
    "1280x720"
    "1920x1080"
    "2560x1440"
    "3840x2160"
    "2560x1080"
    "3440x1440"
    "5120x2160"
)

# Available icon sizes (big small)
ICON_SIZES=(
    "128 80"
    "256 160"
    "384 240"
    "512 320"
)

# Function to find refind.conf
find_refind_conf() {
    printf "${YELLOW}Searching for refind.conf inside /boot (this may take a few seconds)...${RESET}\n"
    local found_path
    found_path=$(find /boot -type f -name refind.conf 2>/dev/null | head -n 1 || true)

    if [ -z "$found_path" ]; then
        printf "${RED}No refind.conf found under /boot.${RESET}\n"
        return 1
    else
        printf "${GREEN}refind.conf found at: ${found_path}${RESET}\n"
        while true; do
            read -rp "$(printf "${bold}Do you want to continue with this file? [Y/n]: ${normal}")" answer
            case "$answer" in
                [Yy]*|"")
                    REFOUND_CONF_PATH="$found_path"
                    return 0
                    ;;
                [Nn]*)
                    return 2
                    ;;
                *)
                    printf "${RED}Please answer yes or no.${RESET}\n"
                    ;;
            esac
        done
    fi
}

# Function to ask for refind.conf path if needed
ask_for_refind_conf() {
    if ! find_refind_conf || [ "$?" -eq 2 ]; then
        printf "${YELLOW}Please enter the full path to your refind.conf file:${RESET}\n"
        read -rp "> " REFOUND_CONF_PATH
    fi
    while [[ ! -f "$REFOUND_CONF_PATH" ]]; do
        printf "${RED}${bold}File not found. Please enter a valid path to refind.conf:${RESET}\n"
        read -rp "> " REFOUND_CONF_PATH
    done
    if [[ ! -w "$REFOUND_CONF_PATH" ]]; then
        printf "${RED}${bold}You do not have write permission for $REFOUND_CONF_PATH${RESET}\n"
        exit 1
    fi
}

# Function to display resolution menu
show_resolution_menu() {
    printf "${CYAN}Select screen resolution:${RESET}\n"
    printf "${bold}1) 1280x720  (HD 16:9)${normal}\n"
    printf "${bold}2) 1920x1080 (Full HD 16:9)${normal}\n"
    printf "${bold}3) 2560x1440 (2k 16:9)${normal}\n"
    printf "${bold}4) 3840x2160 (4k 16:9)${normal}\n"
    printf "${bold}5) 2560x1080 (Full HD Ultrawide 21:9)${normal}\n"
    printf "${bold}6) 3440x1440 (2k Ultrawide 21:9)${normal}\n"
    printf "${bold}7) 5120x2160 (4k Ultrawide 21:9)${normal}\n\n"
}

# Function to get resolution choice
get_resolution_choice() {
    local default_choice=${1:-2}
    read -rp "$(printf "${bold}Enter choice [1-7] (default: $default_choice): ${normal}")" res_select
    res_select=${res_select:-$default_choice}

    # Validate choice
    if [[ "$res_select" -ge 1 && "$res_select" -le 7 ]]; then
        local index=$((res_select - 1))
        printf "%s" "${RESOLUTIONS[$index]}"
    else
        printf "${RED}${bold}Invalid resolution choice.${RESET}\n" >&2
        return 1
    fi
}

# Function to display icon size menu
show_icon_size_menu() {
    printf "${CYAN}Pick an icon size:${RESET}\n"
    printf "${bold}1) Small       (128px - 80px)${normal}\n"
    printf "${bold}2) Medium      (256px - 160px)${normal}\n"
    printf "${bold}3) Large       (384px - 240px)${normal}\n"
    printf "${bold}4) Extra-large (512px - 320px)${normal}\n\n"
}

# Function to get icon size choice
get_icon_size_choice() {
    local default_choice=${1:-1}
    read -rp "$(printf "${bold}Enter choice [1-4] (default: $default_choice): ${normal}")" size_select
    size_select=${size_select:-$default_choice}

    # Validate choice
    if [[ "$size_select" -ge 1 && "$size_select" -le 4 ]]; then
        local index=$((size_select - 1))
        printf "%s" "${ICON_SIZES[$index]}"
    else
        printf "${RED}${bold}Invalid icon size choice.${RESET}\n" >&2
        return 1
    fi
}

# Function to generate theme config
generate_theme_config() {
    local size_big="$1"
    local size_small="$2"
    local res_width="$3"
    local res_height="$4"

    cat > "${INSTALL_DIR}/cachy.conf" << EOF
# Theme by diegons490
big_icon_size $size_big
small_icon_size $size_small
icons_dir themes/cachy/icons
selection_big themes/cachy/icons/selection-big.png
selection_small themes/cachy/icons/selection-small.png
banner themes/cachy/background/background.png
resolution $res_width $res_height
use_graphics_for linux,grub,osx,windows
timeout 10
EOF
}

# Function to install theme
install_theme() {
    clear
    ask_for_refind_conf

    REFIND_DIR=$(dirname "$REFOUND_CONF_PATH")
    INSTALL_DIR="$REFIND_DIR/themes/cachy"

    # Remove old installation if exists
    if [ -d "$INSTALL_DIR" ]; then
        printf "${YELLOW}A previous installation was found at:${RESET} ${bold}$INSTALL_DIR${normal}\n"
        read -rp "$(printf "${bold}Remove it before continuing? [Y/n]: ${normal}")" clean_ans
        case "$clean_ans" in
            [Yy]*|"")
                printf "${YELLOW}Removing...${RESET}\n"
                rm -rf "$INSTALL_DIR"
                ;;
            *)
                printf "${RED}Aborting to avoid overwriting files.${RESET}\n"
                exit 1
                ;;
        esac
    fi

    # Get icon size
    show_icon_size_menu
    icon_sizes=$(get_icon_size_choice 1)
    if [[ $? -ne 0 ]]; then
        exit 1
    fi
    size_big=$(echo "$icon_sizes" | cut -d' ' -f1)
    size_small=$(echo "$icon_sizes" | cut -d' ' -f2)
    printf "\nSelected size: ${GREEN}Big $size_big px, Small $size_small px${RESET}\n\n"

    # Get resolution
    show_resolution_menu
    res=$(get_resolution_choice 2)
    if [[ $? -ne 0 ]]; then
        exit 1
    fi
    res_width="${res%x*}"
    res_height="${res#*x}"
    printf "\nSelected resolution: ${GREEN}${res}${RESET}\n\n"

    printf "${CYAN}Installing theme...${RESET}\n"
    mkdir -p "$INSTALL_DIR/icons" "$INSTALL_DIR/background"
    cp -r "${THEME_DIR}/icons/"* "$INSTALL_DIR/icons/"

    bg_source="${THEME_DIR}/background/background-${res}.png"
    bg_target="${INSTALL_DIR}/background/background.png"
    if [[ ! -f "$bg_source" ]]; then
        printf "${RED}Background not found: $bg_source${RESET}\n"
        exit 1
    fi
    cp "$bg_source" "$bg_target"

    # Generate config
    generate_theme_config "$size_big" "$size_small" "$res_width" "$res_height"

    # Backup + edit refind.conf
    backup_path="${REFOUND_CONF_PATH}.bak.cachy-theme.$(date +%Y%m%d%H%M%S)"
    printf "${YELLOW}Backup: $backup_path${RESET}\n"
    cp "$REFOUND_CONF_PATH" "$backup_path"
    sed -i '/include themes\/cachy\/cachy.conf/d' "$REFOUND_CONF_PATH"
    printf "\n# Load rEFInd theme Cachy\ninclude themes/cachy/cachy.conf\n" >> "$REFOUND_CONF_PATH"

    printf "\n${GREEN}${bold}Installation complete!${RESET}\n"
    printf "Theme: ${bold}$INSTALL_DIR${normal}\n"
    printf "Modified: ${bold}$REFOUND_CONF_PATH${normal}\n"
    printf "Backup: ${bold}$backup_path${normal}\n\n"
}

# Function to uninstall theme
uninstall_theme() {
    clear
    ask_for_refind_conf

    REFIND_DIR=$(dirname "$REFOUND_CONF_PATH")
    INSTALL_DIR="$REFIND_DIR/themes/cachy"

    local backup_file
    backup_file=$(ls -t "${REFOUND_CONF_PATH}".bak.cachy-theme.* 2>/dev/null | head -n 1 || true)

    if [[ ! -f "$backup_file" ]]; then
        printf "${RED}${bold}No backup found (${REFOUND_CONF_PATH}.bak.cachy-theme.*). Cannot proceed.${RESET}\n"
        exit 1
    fi

    printf "${YELLOW}Restoring backup: ${bold}$backup_file${normal}${RESET}\n"
    cp "$backup_file" "$REFOUND_CONF_PATH"

    printf "${YELLOW}Removing theme folder: ${bold}$INSTALL_DIR${normal}${RESET}\n"
    rm -rf "$INSTALL_DIR"

    printf "${YELLOW}Removing all backups created by this theme: ${REFOUND_CONF_PATH}.bak.cachy-theme.*${RESET}\n"
    rm -f "${REFOUND_CONF_PATH}".bak.cachy-theme.*

    printf "\n${GREEN}${bold}Theme removed and backups deleted!${RESET}\n"
}

# Function to reconfigure theme
reconfigure_theme() {
    clear
    ask_for_refind_conf

    REFIND_DIR=$(dirname "$REFOUND_CONF_PATH")
    INSTALL_DIR="$REFIND_DIR/themes/cachy"

    if [[ ! -f "$INSTALL_DIR/cachy.conf" ]]; then
        printf "${RED}${bold}No Cachy theme installation found at: $INSTALL_DIR${RESET}\n"
        exit 1
    fi

    printf "${CYAN}Cachy theme detected at: ${bold}$INSTALL_DIR${normal}${RESET}\n"

    # Get new icon size
    show_icon_size_menu
    icon_sizes=$(get_icon_size_choice 1)
    if [[ $? -ne 0 ]]; then
        exit 1
    fi
    size_big=$(echo "$icon_sizes" | cut -d' ' -f1)
    size_small=$(echo "$icon_sizes" | cut -d' ' -f2)

    # Get new resolution
    show_resolution_menu
    res=$(get_resolution_choice 2)
    if [[ $? -ne 0 ]]; then
        exit 1
    fi
    res_width="${res%x*}"
    res_height="${res#*x}"

    bg_source="${THEME_DIR}/background/background-${res}.png"
    bg_target="${INSTALL_DIR}/background/background.png"

    if [[ ! -f "$bg_source" ]]; then
        printf "${RED}Background not found: $bg_source${RESET}\n"
        exit 1
    fi

    cp "$bg_source" "$bg_target"

    printf "${YELLOW}Updating cachy.conf...${RESET}\n"
    generate_theme_config "$size_big" "$size_small" "$res_width" "$res_height"

    printf "\n${GREEN}${bold}Reconfiguration complete!${RESET}\n"
    printf "Updated resolution: ${bold}${res}${normal}\n"
    printf "Icon sizes: ${bold}Big $size_big px, Small $size_small px${normal}\n\n"
}

# Main menu
clear
printf "${bold}${CYAN}######################################${RESET}\n"
printf "${bold}${CYAN}### rEFInd CachyOS Theme Installer ###${RESET}\n"
printf "${bold}${CYAN}######################################${RESET}\n"
printf "\n"
printf "${bold}1) Install theme\n"
printf "2) Remove theme and restore backup\n"
printf "3) Reconfigure resolution and icon size\n"
printf "0) Cancel${normal}\n"
printf "\n"
read -rp "$(printf "${bold}Choose an option [0-3]: ${normal}")" menu_choice

case "$menu_choice" in
    1) install_theme ;;
    2) uninstall_theme ;;
    3) reconfigure_theme ;;
    0) printf "${YELLOW}Cancelled by user.${RESET}\n" && exit 0 ;;
    *) printf "${RED}Invalid option. Exiting.${RESET}\n" && exit 1 ;;
esac
