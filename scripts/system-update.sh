#!/usr/bin/env bash
#
# Check for package updates and upgrade them for Debian/Ubuntu
# When run with "module" argument, output status in JSON format for Waybar
#
# Requirements:
# - apt
# - notify-send (libnotify)
#
# Modified for Debian

TIMEOUT=10
FAILURE=false
APT_UPD=0

cprintf() {
	case $1 in
		green) printf "\e[32m" ;;
		blue)  printf "\e[34m" ;;
	esac

	printf "%b%b\n" "${@:2}" "\e[39m" >&2
}

check_updates() {
	local apt_output apt_status
	
	# Package lists are refreshed by apt-daily.timer (root), no sudo here
	# Get upgradable packages
	# status of apt itself, not grep (grep exits 1 when there are 0 updates)
	apt_output=$(apt list --upgradable 2>/dev/null)
	apt_status=$?

	if ((apt_status != 0)); then
		FAILURE=true
		return 1
	fi

	APT_UPD=$(grep -c "upgradable from" <<< "$apt_output")
}

update_packages() {
	cprintf blue "Updating apt packages..."
	sudo apt-get update && sudo apt-get upgrade -y

	notify-send "Update Complete" -i "package-install" -t 3000

	cprintf green "\nUpdate Complete!"
	read -rsn 1 -p "Press any key to exit..."
}

display_module() {
	if $FAILURE; then
		echo "{ \"text\": \"󰒑\", \"tooltip\": \"Cannot fetch updates. Right-click to retry.\" }"
		exit 0
	fi

	local tooltip="<b>APT Updates</b>: $APT_UPD"

	if ((APT_UPD == 0)); then
		echo "{ \"text\": \"󰸟\", \"tooltip\": \"No updates available\" }"
	else
		echo "{ \"text\": \"󰄠\", \"tooltip\": \"$tooltip\" }"
	fi
}

main() {
	case $1 in
		"module")
			check_updates
			display_module
			;;
		*)
			cprintf blue "Checking for updates..."
			check_updates

			update_packages
			pkill -RTMIN+1 waybar
			;;
	esac
}

main "$@"
