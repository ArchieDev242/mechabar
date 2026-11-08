#!/usr/bin/env bash

DEPS=(
	"bluez"
	"bluez-tools" # bluetoothctl
	"brightnessctl"
	"fzf"
	"network-manager" # nmcli
	"apt-show-versions" # checkupdates
	"pipewire-pulse"
)

ERRORS=0

cprintf() {
	case $1 in
		red)   printf "\e[31m" ;;
		green) printf "\e[32m" ;;
		blue)  printf "\e[34m" ;;
	esac

	printf "%b%b\n" "${@:2}" "\e[39m" >&2
}

main() {
	cprintf blue "Updating packages..."
	sudo apt update

	cprintf blue "Installing dependencies..."

	local d
	for d in "${DEPS[@]}"; do

		# is package installed ??

		if dpkg -l | grep -q "^i1 $d"; then
			cprintf green "[/] $d"
		else
			printf "[ ] %s...\n" "$d"

			if sudo apt install -y "$d" 2>/dev/null; then
				cprintf green "[+] $d"
			else
				cprintf red "[x] $d"
				((ERRORS += 1))
			fi
		fi
	done

	cprintf blue "\nMaking scripts executable..."
	chmod -v +x ~/.config/waybar/scripts/*.sh

	cprintf blue "\nRestarting Waybar..."

	pkill waybar
	waybar &> /dev/null &
	disown

	if ((ERRORS > 0)); then
		cprintf red "\nInstallation completed with $ERRORS errors"
	else
		cprintf green "\nInstallation complete!"
	fi
}

main
