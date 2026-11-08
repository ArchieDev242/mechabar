#!/usr/bin/env bash

WAYBAR_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

DEPS=(
	"waybar"
	"bluez"            # bluetoothctl
	"brightnessctl"
	"fzf"              # bluetooth-tui.sh
	"kitty"            # system update on-click
	"libnotify-bin"    # notify-send
	"ncal"             # cal, calendar-menu.sh
	"network-manager"  # nmcli
	"pavucontrol"
	"pipewire-pulse"
	"pulseaudio-utils" # pactl
	"rofi"
	"wireplumber"      # wpctl
)

FONT="JetBrainsMono Nerd Font"

ERRORS=0

cprintf() {
	case $1 in
		red)    printf "\e[31m" ;;
		green)  printf "\e[32m" ;;
		yellow) printf "\e[33m" ;;
		blue)   printf "\e[34m" ;;
	esac

	printf "%b%b\n" "${@:2}" "\e[39m" >&2
}

is_installed() {
	dpkg-query -W -f='${Status}' "$1" 2>/dev/null | grep -q "install ok installed"
}

main() {
	cprintf blue "Updating packages..."
	sudo apt update

	cprintf blue "\nInstalling dependencies..."

	local d
	for d in "${DEPS[@]}"; do
		if is_installed "$d"; then
			cprintf green "[/] $d"
		else
			printf "[ ] %s...\n" "$d"

			if sudo apt install -y "$d" &>/dev/null; then
				cprintf green "[+] $d"
			else
				cprintf red "[x] $d"
				((ERRORS += 1))
			fi
		fi
	done

	cprintf blue "\nChecking font..."
	if fc-list | grep -q "$FONT"; then
		cprintf green "[/] $FONT"
	else
		cprintf yellow "[!] $FONT not found, icons will be broken"
		cprintf yellow "    get it: https://github.com/ryanoasis/nerd-fonts/releases (JetBrainsMono.zip)"
		cprintf yellow "    unzip into ~/.local/share/fonts/ and run: fc-cache -f"
	fi

	if [[ ! -f ~/.config/rofi/config.rasi ]]; then
		cprintf yellow "\n[!] ~/.config/rofi/config.rasi missing, rofi menus use it"
	fi

	cprintf blue "\nMaking scripts executable..."
	chmod -v +x "$WAYBAR_DIR"/scripts/*.sh

	cprintf blue "\nRestarting Waybar..."
	pkill waybar
	waybar &>/dev/null &
	disown

	if ((ERRORS > 0)); then
		cprintf red "\nInstallation completed with $ERRORS errors"
	else
		cprintf green "\nInstallation complete!"
	fi
}

main
