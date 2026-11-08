#!/usr/bin/env bash
#
# Launch a power menu with rofi
#
# Requirement: rofi
#
# Author:  Jesse Mirabel <sejjymvm@gmail.com>
# Date:    August 19, 2025
# License: MIT

main() {
	local list=(
		"Lock"
		"Suspend"
		"Hibernate"
		"Logout"
		"Reboot"
		"Shutdown"
	)

	local selected
	selected=$(printf "%s\n" "${list[@]}" | rofi -dmenu -p "󰤄 Power Menu" -config ~/.config/rofi/config.rasi -theme-str 'window {width: 30%;}')

	case $selected in
		"Lock")      loginctl lock-session ;;
		"Suspend")   systemctl suspend ;;
		"Hibernate") systemctl hibernate ;;
		"Logout")    loginctl terminate-session "$XDG_SESSION_ID" ;;
		"Reboot")    systemctl reboot ;;
		"Shutdown")  systemctl poweroff ;;
		*)           exit 1 ;;
	esac
}

main
