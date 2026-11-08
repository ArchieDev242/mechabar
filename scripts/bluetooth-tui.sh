#!/usr/bin/env bash
#
# Bluetooth TUI - runs in terminal for smooth UX
# Requirements: fzf, bluetoothctl, hcitool
#

TERM_HEIGHT=12
SPINNER=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')

scan_devices() {
	bluetoothctl power on 2>/dev/null || true
	pkill -f "bluetoothctl scan" 2>/dev/null || true
	sleep 1

	# Scan for Bluetooth devices (including classic BT for headphones)
	bluetoothctl scan on 2>/dev/null &
	local scan_pid=$!
	local scan_time=18
	for i in $(seq 1 $scan_time); do
		printf "\r  ${SPINNER[i % 10]} Scanning... %d/%ds  " "$i" "$scan_time"
		sleep 1
	done
	bluetoothctl scan off 2>/dev/null || true
	wait $scan_pid 2>/dev/null || true
	sleep 1

	local all_devices
	all_devices=$(bluetoothctl devices 2>/dev/null)

	# Fallback: hcitool finds classic BT when bluetoothctl doesn't
	if [[ -z "$all_devices" ]]; then
		printf "\r  Scanning (hcitool)...          \n"
		local hci_raw
		hci_raw=$(timeout 15 hcitool scan 2>/dev/null | tail -n +2)
		if [[ -n "$hci_raw" ]]; then
			all_devices=$(echo "$hci_raw" | awk '{print "Device " $1 " " substr($0, index($0,$2))}')
		fi
	fi

	printf "\r  Done.                            \n\n"
	echo "$all_devices"
}

show_devices() {
	local devices
	devices=$(bluetoothctl devices 2>/dev/null)
	if [[ -z "$devices" ]]; then
		echo "No devices found."
		echo ""
		read -r -p "Press Enter to close..."
		return
	fi

	echo "═══ Paired/Connected devices ═══"
	echo "$devices" | while IFS= read -r line; do
		local mac=$(echo "$line" | awk '{print $2}')
		local name=$(echo "$line" | awk '{$1=$2=""; print substr($0,3)}')
		local connected=$(bluetoothctl info "$mac" 2>/dev/null | grep "Connected:" | awk '{print $2}')
		local status=""
		[[ "$connected" == "yes" ]] && status=" ✓"
		printf "  %-17s %s%s\n" "$mac" "$name" "$status"
	done
	echo ""
	read -r -p "Press Enter to close..."
}

connect_device() {
	local devices
	devices=$(scan_devices)
	if [[ -z "$devices" ]]; then
		echo "No devices found. Enable pairing mode."
		sleep 2
		return
	fi

	local list
	list=$(echo "$devices" | awk '{mac=$2; name=substr($0, index($0,$3)); print mac "  " name}')
	local mac
	mac=$(echo "$list" | fzf --height="$TERM_HEIGHT" --border=sharp --border-label="  Select Device  " \
		--header="↑↓ navigate  Enter select  Esc cancel" --reverse --with-nth=2.. | awk '{print $1}')

	[[ -z "$mac" ]] && return

	local name
	name=$(echo "$devices" | grep "Device $mac " | awk '{print substr($0, index($0,$3))}')
	echo ""
	echo "  Connecting to: $name"

	# Check if already connected
	if bluetoothctl info "$mac" 2>/dev/null | grep -q "Connected: yes"; then
		echo "  Already connected."
		sleep 2
		return
	fi

	bluetoothctl disconnect "$mac" 2>/dev/null || true
	sleep 1

	# For hcitool devices: bluetoothctl needs to know device before pair - run scan first
	if ! bluetoothctl info "$mac" 2>/dev/null | grep -q "Name:"; then
		echo "  Discovering device (8s)..."
		bluetoothctl scan bredr 2>/dev/null &
		local disc_pid=$!
		sleep 8
		kill $disc_pid 2>/dev/null || true
		bluetoothctl scan off 2>/dev/null || true
		sleep 2
	fi

	# Pair if needed
	if ! bluetoothctl info "$mac" 2>/dev/null | grep -q "Paired: yes"; then
		echo "  Pairing..."
		if ! timeout 25 bluetoothctl pair "$mac" 2>/dev/null; then
			echo "  Pair failed. Is pairing mode on?"
			sleep 3
			return 1
		fi
		sleep 2
	fi

	bluetoothctl trust "$mac" 2>/dev/null || true
	sleep 1

	# Connect with retries
	local retry=0
	while [[ $retry -lt 5 ]]; do
		if bluetoothctl connect "$mac" 2>&1 | grep -q "Connection successful"; then
			echo "  ✓ Connected!"
			notify-send "Bluetooth" "Connected: $name" -i bluetooth -t 3000 2>/dev/null
			sleep 2
			return 0
		fi
		((retry++))
		echo "  Retry $retry/5..."
		sleep 3
	done

	echo "  Connection failed."
	notify-send "Bluetooth" "Failed: $name" -i bluetooth -u critical -t 4000 2>/dev/null
	sleep 3
}

main_menu() {
	local options=(
		"󰂱   Connect Device"
		"󰖓   Disconnect"
		"󰖆   Show Devices"
		"󰂰   Enable Bluetooth"
		"󰂲   Disable Bluetooth"
	)
	local selected
	selected=$(printf "%s\n" "${options[@]}" | fzf --height=10 --border=sharp --border-label="  Bluetooth  " \
		--header="↑↓ navigate  Enter select" --reverse)

	case "$selected" in
		*"Connect Device")
			connect_device
			;;
		*"Disconnect")
			bluetoothctl disconnect 2>/dev/null
			echo "  Disconnected."
			notify-send "Bluetooth" "Disconnected" -i bluetooth -t 3000 2>/dev/null
			sleep 2
			;;
		*"Show Devices")
			show_devices
			;;
		*"Enable Bluetooth")
			bluetoothctl power on 2>/dev/null
			echo "  Bluetooth enabled."
			sleep 2
			;;
		*"Disable Bluetooth")
			bluetoothctl power off 2>/dev/null
			echo "  Bluetooth disabled."
			sleep 2
			;;
		*)
			exit 0
			;;
	esac
}

clear
while true; do
	main_menu
	clear
done
