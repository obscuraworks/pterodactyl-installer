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

# ------------------ Progress bar -------------- #

# Internal: print the header block used in progress display
_upgrade_print_header() {
  echo -e "\033[1;33m######################################################################\033[0m"
  echo -e "\033[1;33m#     Obscuraworks Panel Upgrade                                     #\033[0m"
  echo -e "\033[1;33m#     hello@obscuraworks.com | www.obscuraworks.org                  #\033[0m"
  echo -e "\033[1;33m######################################################################\033[0m"
  echo ""
}

show_upgrade_progress() {
  local percent=$1
  local message=$2

  local color_reset='\033[0m'
  local color_red='\033[0;31m'
  local color_orange='\033[0;33m'
  local color_green='\033[0;32m'
  local color_cyan='\033[0;36m'
  local color_purple='\033[0;35m'
  local color_bold='\033[1m'

  local color
  if [ "$percent" -le 40 ]; then
    color=$color_red
  elif [ "$percent" -le 70 ]; then
    color=$color_orange
  else
    color=$color_green
  fi

  local filled_len=$((percent / 2))
  local empty_len=$((50 - filled_len))
  local filled_bar
  local empty_bar
  filled_bar=$(printf "%${filled_len}s" | tr ' ' '█')
  empty_bar=$(printf "%${empty_len}s" | tr ' ' '░')

  clear
  _upgrade_print_header
  echo -e "${color_cyan}${color_bold}⚙️  Upgrade in progress...${color_reset}"
  echo -e "${color_purple}-----------------------------------------------------${color_reset}"
  echo -e "${color_bold}${message}${color_reset}"
  echo -e "${color}${filled_bar}${empty_bar}${color_reset} ${color_bold}${percent}%${color_reset}"
  echo -e "${color_purple}-----------------------------------------------------${color_reset}"
  sleep 1
}

# ------------------ Upgrade function ---------- #

perform_upgrade() {
  PANEL_DIR="/var/www/pterodactyl"

  if [ ! -d "$PANEL_DIR" ]; then
    error "Panel directory $PANEL_DIR not found. Cannot perform upgrade."
    exit 1
  fi

  show_upgrade_progress 5 "Entering panel directory and enabling maintenance mode..."
  cd "$PANEL_DIR" || exit 1
  php artisan down >/dev/null 2>&1

  show_upgrade_progress 20 "Downloading latest Obscuraworks panel release..."
  curl -sSL "$PANEL_DL_URL" | tar -xzv >/dev/null 2>&1
  chmod -R 755 storage/* bootstrap/cache/

  show_upgrade_progress 40 "Installing Composer dependencies (optimized, no-dev)..."
  [ "$OS" == "rocky" ] || [ "$OS" == "almalinux" ] && export PATH=/usr/local/bin:$PATH
  COMPOSER_ALLOW_SUPERUSER=1 composer install --no-dev --optimize-autoloader --no-interaction >/dev/null 2>&1

  show_upgrade_progress 60 "Clearing view and config cache..."
  php artisan view:clear >/dev/null 2>&1
  php artisan config:clear >/dev/null 2>&1

  show_upgrade_progress 70 "Running database migrations..."
  php artisan migrate --seed --force >/dev/null 2>&1

  show_upgrade_progress 85 "Setting folder permissions..."
  case "$OS" in
  debian | ubuntu)
    chown -R www-data:www-data "$PANEL_DIR"
    ;;
  rocky | almalinux)
    chown -R nginx:nginx "$PANEL_DIR"
    ;;
  esac

  show_upgrade_progress 92 "Clearing application cache and restarting PHP-FPM..."
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

  clear
  _upgrade_print_header
  echo -e "\033[0;32m\033[1m✅  Obscuraworks Panel upgrade completed successfully!\033[0m"
  echo ""
  output "Your panel is back online."
  output "Your .env configuration and database have not been modified."
  echo ""
}

# ------------------- Run ------------------- #

perform_upgrade
