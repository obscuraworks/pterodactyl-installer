#!/bin/bash

set -e

######################################################################################
#                                                                                    #
# Project 'pterodactyl-installer'                                                    #
#                                                                                    #
# Original work Copyright (C) 2018 - 2026, Vilhelm Prytz <vilhelm@prytznet.se>      #
# https://github.com/pterodactyl-installer/pterodactyl-installer                     #
#                                                                                    #
# Modified & maintained by:                                                          #
# PT OBSCURAWORKS DIGITAL INDONESIA                                                  #
# hello@obscuraworks.com | www.obscuraworks.org                                      #
#                                                                                    #
# Copyright (C) 2025 - 2026, PT Obscuraworks Digital Indonesia                       #
#                                                                                    #
# This is a modified fork of the original pterodactyl-installer script,              #
# customized for use with the Obscuraworks custom panel. This fork is                #
# independently maintained by Obscuraworks and is not affiliated with the            #
# official Pterodactyl Project.                                                      #
#                                                                                    #
#   This program is free software: you can redistribute it and/or modify             #
#   it under the terms of the GNU General Public License as published by             #
#   the Free Software Foundation, either version 3 of the License, or                #
#   (at your option) any later version.                                              #
#                                                                                    #
#   This program is distributed in the hope that it will be useful,                  #
#   but WITHOUT ANY WARRANTY; without even the implied warranty of                   #
#   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the                    #
#   GNU General Public License for more details.                                     #
#                                                                                    #
#   You should have received a copy of the GNU General Public License                #
#   along with this program.  If not, see <https://www.gnu.org/licenses/>.           #
#                                                                                    #
# https://github.com/obscuraworks/pterodactyl-installer/blob/master/LICENSE          #
#                                                                                    #
######################################################################################

# Check if script is loaded, load if not or fail otherwise.
fn_exists() { declare -F "$1" >/dev/null; }
if ! fn_exists lib_loaded; then
  # shellcheck source=lib/lib.sh
  source /tmp/lib.sh || source <(curl -sSL "$GITHUB_BASE_URL/$GITHUB_SOURCE"/lib/lib.sh)
  ! fn_exists lib_loaded && echo "* ERROR: Could not load lib script" && exit 1
fi

# ─────────────────────────────────────────────
# COLOR PALETTE
# ─────────────────────────────────────────────
RST='\033[0m'
BOLD='\033[1m'
DIM='\033[2m'

# Amber — primary brand accent
AMBER='\033[38;5;214m'
AMBER_B='\033[1;38;5;214m'

# Neutral grays
GRAY='\033[38;5;240m'
LGRAY='\033[38;5;248m'

# Status colors
GREEN='\033[38;5;78m'
RED='\033[38;5;203m'
BLUE='\033[38;5;111m'

# ─────────────────────────────────────────────
# HEADER
# ─────────────────────────────────────────────
_upgrade_print_header() {
  local W=70
  local top bot mid

  top="╔$(printf '═%.0s' $(seq 1 $((W-2))))╗"
  bot="╚$(printf '═%.0s' $(seq 1 $((W-2))))╝"
  mid="║$(printf ' %.0s' $(seq 1 $((W-2))))║"

  echo -e "${AMBER}${top}${RST}"
  echo -e "${AMBER}${mid}${RST}"
  printf '%b' "${AMBER}║${RST}  ${AMBER_B}◈  OBSCURAWORKS PANEL UPGRADE${RST}$(printf ' %.0s' $(seq 1 $((W-33))))${AMBER}║${RST}\n"
  printf '%b' "${AMBER}║${RST}  ${DIM}${LGRAY}hello@obscuraworks.com  ·  www.obscuraworks.org${RST}$(printf ' %.0s' $(seq 1 $((W-51))))${AMBER}║${RST}\n"
  echo -e "${AMBER}${mid}${RST}"
  echo -e "${AMBER}${bot}${RST}"
  echo ""
}

# ─────────────────────────────────────────────
# PROGRESS BAR
# ─────────────────────────────────────────────
show_upgrade_progress() {
  local percent=$1
  local message=$2

  # Bar sizing
  local bar_width=50
  local filled_len=$(( percent * bar_width / 100 ))
  local empty_len=$(( bar_width - filled_len ))

  local filled_bar empty_bar
  filled_bar=$(printf "%${filled_len}s" | tr ' ' '█')
  empty_bar=$(printf "%${empty_len}s" | tr ' ' '░')

  # Dynamic bar color based on progress
  local bar_color
  if [ "$percent" -le 30 ]; then
    bar_color=$BLUE
  elif [ "$percent" -le 70 ]; then
    bar_color=$AMBER
  else
    bar_color=$GREEN
  fi

  # Step indicator
  local step_icon="○"
  [ "$percent" -ge 100 ] && step_icon="●"

  clear
  _upgrade_print_header

  echo -e "  ${LGRAY}${DIM}PROGRESS${RST}"
  echo -e "  ${GRAY}───────────────────────────────────────────────────${RST}"
  echo ""
  printf "  ${bar_color}${BOLD}%s%s${RST}  ${AMBER_B}%3d%%${RST}\n" "$filled_bar" "$empty_bar" "$percent"
  echo ""
  echo -e "  ${step_icon}  ${LGRAY}${message}${RST}"
  echo ""
  echo -e "  ${GRAY}───────────────────────────────────────────────────${RST}"
  echo -e "  ${DIM}${GRAY}Pterodactyl Installer  ·  github.com/obscuraworks/pterodactyl-installer${RST}"

  sleep 1
}

# ─────────────────────────────────────────────
# UPGRADE LOGIC
# ─────────────────────────────────────────────
perform_upgrade() {
  PANEL_DIR="/var/www/pterodactyl"

  if [ ! -d "$PANEL_DIR" ]; then
    echo -e "\n  ${RED}${BOLD}✖  ERROR:${RST} Panel directory ${BOLD}${PANEL_DIR}${RST} not found."
    echo -e "  ${GRAY}Cannot perform upgrade. Aborting.${RST}\n"
    exit 1
  fi

  show_upgrade_progress 5  "Enabling maintenance mode..."
  cd "$PANEL_DIR" || exit 1
  php artisan down >/dev/null 2>&1

  show_upgrade_progress 20 "Downloading latest Obscuraworks panel release..."
  rm -rf "$PANEL_DIR/resources/scripts"
  curl -sSL "$PANEL_DL_URL" | tar -xzv >/dev/null 2>&1
  chmod -R 755 storage/* bootstrap/cache/

  show_upgrade_progress 40 "Installing Composer dependencies (no-dev, optimized)..."
  [ "$OS" == "rocky" ] || [ "$OS" == "almalinux" ] && export PATH=/usr/local/bin:$PATH
  COMPOSER_ALLOW_SUPERUSER=1 composer install --no-dev --optimize-autoloader --no-interaction >/dev/null 2>&1

  show_upgrade_progress 60 "Clearing view and config cache..."
  php artisan view:clear >/dev/null 2>&1
  php artisan config:clear >/dev/null 2>&1

  show_upgrade_progress 70 "Running database migrations..."
  php artisan migrate --seed --force >/dev/null 2>&1

  show_upgrade_progress 85 "Setting folder ownership and permissions..."
  case "$OS" in
  debian | ubuntu) chown -R www-data:www-data "$PANEL_DIR" ;;
  rocky | almalinux) chown -R nginx:nginx "$PANEL_DIR" ;;
  esac

  show_upgrade_progress 92 "Clearing application cache — restarting PHP-FPM..."
  case "$OS" in
  debian | ubuntu)
    sudo -u www-data php artisan optimize:clear >/dev/null 2>&1
    systemctl restart php8.3-fpm
    ;;
  rocky | almalinux)
    sudo -u nginx php artisan optimize:clear >/dev/null 2>&1
    systemctl restart php-fpm
    ;;
  esac

  show_upgrade_progress 100 "Bringing panel back online..."
  php artisan up >/dev/null 2>&1

  # ── Success Screen ──────────────────────────────────────
  clear
  _upgrade_print_header

  echo -e "  ${GREEN}${BOLD}✔  Upgrade completed successfully.${RST}"
  echo ""
  echo -e "  ${GRAY}─────────────────────────────────────────────────${RST}"
  echo -e "  ${LGRAY}Your panel is back online and fully operational.${RST}"
  echo -e "  ${DIM}${GRAY}Your .env configuration and database have not been modified.${RST}"
  echo -e "  ${GRAY}─────────────────────────────────────────────────${RST}"
  echo ""
  echo -e "  ${DIM}${GRAY}Need help? → hello@obscuraworks.com${RST}"
  echo ""
}

# ─────────────────────────────────────────────
# ENTRYPOINT
# ─────────────────────────────────────────────
perform_upgrade
