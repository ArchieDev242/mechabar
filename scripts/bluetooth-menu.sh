#!/usr/bin/env bash
#
# Launch a Bluetooth menu with rofi
#

main() {
	local list=(
		"󰂱  Connect Device"
		"󰖓  Disconnect"
		"󰂰  Enable Bluetooth"
		"󰂲  Disable Bluetooth"
		"󰖆  Show Devices"
	)

	local selected
	selected=$(printf "%s\n" "${list[@]}" | rofi -dmenu -p "󰂱 Bluetooth Menu" -config ~/.config/rofi/config.rasi -theme-str "window { width: 35%; }" 2>/dev/null)

	case $selected in
		*"Connect Device")
			# Enable discoverable mode
			bluetoothctl power on 2>/dev/null
			bluetoothctl discoverable on 2>/dev/null
			bluetoothctl pairable on 2>/dev/null
			
			notify-send "Bluetooth" "Mode: Discoverable & Pairable ON" -i bluetooth -t 3000
			
			rofi -e "\n⠋ Scanning...\n\nEnable pairing on your device!" -config ~/.config/rofi/config.rasi -theme-str "window { width: 40%; height: 20%; }" 2>/dev/null &
			local rofi_pid=$!
			
			# Kill existing scans
			pkill -f "bluetoothctl scan" 2>/dev/null
			sleep 1
			
			# Start scan
			bluetoothctl scan on 2>/dev/null &
			local scan_pid=$!
			sleep 10
			kill $scan_pid 2>/dev/null
			kill $rofi_pid 2>/dev/null
			
			# Get all devices
			local all_devices=$(bluetoothctl devices 2>/dev/null)
			
			if [[ -z "$all_devices" ]]; then
				notify-send "Bluetooth" "No devices found. Try 'Show Devices'" -i bluetooth -u normal -t 3000
				bluetoothctl discoverable off 2>/dev/null
				bluetoothctl pairable off 2>/dev/null
				return 1
			fi
			
			local device
			device=$(echo "$all_devices" | awk '{$1=""; print $0}' | sed 's/^ /󰂱 /' | \
				rofi -dmenu -p "󰖆 Select" -config ~/.config/rofi/config.rasi -theme-str "window { width: 50%; height: 60%; }" 2>/dev/null)
			
			if [[ -n "$device" ]]; then
				local name=$(echo "$device" | sed 's/󰂱 //')
				local mac=$(echo "$all_devices" | grep "$name" | awk '{print $2}' | head -1)
				
				if [[ -z "$mac" ]]; then
					notify-send "Bluetooth" "Device not found" -i bluetooth -u critical -t 4000
				else
					notify-send "Bluetooth" "Connecting to $name..." -i bluetooth -t 3000
					bluetoothctl pair "$mac" 2>/dev/null || true
					sleep 1
					bluetoothctl trust "$mac" 2>/dev/null || true
					sleep 1
					
					if bluetoothctl connect "$mac" 2>/dev/null; then
						notify-send "Bluetooth" "✓ Connected: $name" -i bluetooth -t 3000
					else
						notify-send "Bluetooth" "Check logs or try manual connection" -i bluetooth -u normal -t 4000
					fi
				fi
			fi
			
			# Disable modes when done
			sleep 2
			bluetoothctl discoverable off 2>/dev/null
			bluetoothctl pairable off 2>/dev/null
			;;
		*"Disconnect")
			bluetoothctl disconnect 2>/dev/null
			notify-send "Bluetooth" "Disconnected" -i bluetooth -t 3000
			;;
		*"Enable Bluetooth")
			bluetoothctl power on 2>/dev/null
			notify-send "Bluetooth" "Enabled" -i bluetooth -t 3000
			;;
		*"Disable Bluetooth")
			bluetoothctl power off 2>/dev/null
			notify-send "Bluetooth" "Disabled" -i bluetooth -t 3000
			;;
		*"Show Devices")
			local devices=$(bluetoothctl devices 2>/dev/null)
			if [[ -z "$devices" ]]; then
				rofi -e "No devices paired yet" -config ~/.config/rofi/config.rasi 2>/dev/null
			else
				echo -e "$(bluetoothctl show | grep 'Name:\|Alias:\|Powered')\n\n$(bluetoothctl devices)" | \
					rofi -dmenu -p "󰂱 Info" -config ~/.config/rofi/config.rasi -theme-str "window { width: 50%; height: 70%; }" 2>/dev/null
			fi
			;;
		*)
			exit 1
			;;
	esac
}

main
