#!/usr/bin/env bash
#
# Launch a Wi-Fi menu with rofi
#
# Requirement: rofi, nmcli
#

main() {
	local list=(
		"󰤰  Connect to Network"
		"󰖓  Disconnect"
		"󰤨  Enable Wi-Fi"
		"󰤯  Disable Wi-Fi"
		"󰖆  Rescan Networks"
	)

	local selected
	selected=$(printf "%s\n" "${list[@]}" | rofi -dmenu 2>/dev/null -p "󰤨 Wi-Fi Menu" -config ~/.config/rofi/config.rasi -theme-str 'window {width: 35%;}')

	case $selected in
		*"Connect to Network")
			# Show scanning animation
			rofi -e 2>/dev/null "\n⠋ Scanning for networks...\n\nPlease wait..." -config ~/.config/rofi/config.rasi -theme-str 'window {width: 40%; height: 150;}' 2>/dev/null &
			local rofi_pid=$!
			sleep 1
			
			local networks
			# Get network list with signal strength and security
			networks=$(nmcli -f SSID,SIGNAL,SECURITY dev wifi list --rescan yes 2>/dev/null | \
				awk 'NR>1 && $1 != "--" {printf "󰤨 %s (%s%%) [%s]\n", $1, $2, (NF>2 ? $3 : "Open")}' | \
				rofi -dmenu 2>/dev/null -p "󰖆 Select Network" -config ~/.config/rofi/config.rasi -theme-str 'window {width: 50%; height: 400;}' 2>/dev/null)
			kill $rofi_pid 2>/dev/null
			
			if [[ -n "$networks" ]]; then
				local ssid=$(echo "$networks" | sed 's/^.*󰤨 \([^ ]*\) .*/\1/')
				# Check if network requires password
				if echo "$networks" | grep -q "\[WPA\|\[WEP"; then
					local password
					password=$(rofi -dmenu 2>/dev/null -password -p "󰕵 Password for $ssid" -config ~/.config/rofi/config.rasi -theme-str 'window {width: 40%;}')
					if [[ -n "$password" ]]; then
						nmcli dev wifi connect "$ssid" password "$password" && \
							notify-send "Wi-Fi" "Connected to $ssid" -i network-wireless || \
							notify-send "Wi-Fi" "Failed to connect to $ssid" -i network-wireless-off -u critical
					fi
				else
					nmcli dev wifi connect "$ssid" && \
						notify-send "Wi-Fi" "Connected to $ssid" -i network-wireless || \
						notify-send "Wi-Fi" "Failed to connect to $ssid" -i network-wireless-off -u critical
				fi
			fi
			;;
		*"Disconnect")
			nmcli con down id "$(nmcli -t -f NAME con show --active | head -1)" 2>/dev/null
			notify-send "Wi-Fi" "Disconnected" -i network-wireless-off
			;;
		*"Enable Wi-Fi")
			nmcli radio wifi on
			notify-send "Wi-Fi" "Enabled" -i network-wireless
			;;
		*"Disable Wi-Fi")
			nmcli radio wifi off
			notify-send "Wi-Fi" "Disabled" -i network-wireless-off
			;;
		*"Rescan Networks")
			rofi -e 2>/dev/null "\n⠋ Rescanning networks...\n\nPlease wait..." -config ~/.config/rofi/config.rasi -theme-str 'window {width: 40%; height: 150;}' &
			local rofi_pid=$!
			nmcli dev wifi rescan
			sleep 2
			kill $rofi_pid 2>/dev/null
			notify-send "Wi-Fi" "Rescan complete" -i network-wireless
			;;
		*)
			exit 1
			;;
	esac
}

main
