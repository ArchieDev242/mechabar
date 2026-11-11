#!/usr/bin/env bash
#
# Adjust default device volume and send a notification with the current level
#
# Requirements:
# - wpctl (WirePlumber) or pactl (libpulse)
# - notify-send (libnotify)
#
# Author:  Jesse Mirabel <sejjymvm@gmail.com>
# Date:    September 07, 2025
# License: MIT

DEF_VALUE=5
MIN=0
MAX=100

DEVICE=
ACTION=
VALUE=

DEV_DEF=
DEV_STATE=
DEV_VOLUME=
DEV_ICON=
DEV_NAME=

usage() {
	local script=${0##*/}

	cat <<- EOF
		USAGE: $script {input|output} {mute|raise|lower} [value]

		Adjust default device volume and send a notification with the current level

		DEVICE:
		  input            Use "@DEFAULT_AUDIO_SOURCE@" (microphone)
		  output           Use "@DEFAULT_AUDIO_SINK@" (speaker/headphones)

		OPTIONS:
		  mute             Toggle device mute
		  raise [value]    Raise volume by [value] (default: $DEF_VALUE)
		  lower [value]    Lower volume by [value] (default: $DEF_VALUE)

		EXAMPLES:
		  Toggle microphone mute:
		    $ $script input mute

		  Raise speaker volume:
		    $ $script output raise

		  Lower speaker volume by 5:
		    $ $script output lower 5
	EOF
}

# Use wpctl if available (PipeWire), else pactl (PulseAudio)
if command -v wpctl >/dev/null && wpctl status 2>/dev/null | grep -q "Audio"; then
	AUDIO_BACKEND="wpctl"
else
	AUDIO_BACKEND="pactl"
fi

get_volume() {
	if [[ $AUDIO_BACKEND == "wpctl" ]]; then
		wpctl get-volume "$DEV_DEF" | awk '{printf "%.0f", $2*100}'
	else
		pactl get-sink-volume "$DEV_DEF" 2>/dev/null | awk '{print $5}' | tr -d "%" || \
		pactl get-source-volume "$DEV_DEF" 2>/dev/null | awk '{print $5}' | tr -d "%"
	fi
}

get_mute() {
	if [[ $AUDIO_BACKEND == "wpctl" ]]; then
		wpctl get-volume "$DEV_DEF" | grep -q "MUTED" && echo "yes" || echo "no"
	else
		pactl get-sink-mute "$DEV_DEF" 2>/dev/null | awk '{print $2}' || \
		pactl get-source-mute "$DEV_DEF" 2>/dev/null | awk '{print $2}'
	fi
}

set_volume() {
	local new_level=$1
	if [[ $AUDIO_BACKEND == "wpctl" ]]; then
		wpctl set-volume "$DEV_DEF" "${new_level}%"
	else
		pactl set-sink-volume "$DEV_DEF" "${new_level}%" 2>/dev/null || \
		pactl set-source-volume "$DEV_DEF" "${new_level}%"
	fi
}

set_mute() {
	if [[ $AUDIO_BACKEND == "wpctl" ]]; then
		wpctl set-mute "$DEV_DEF" toggle
	else
		pactl set-sink-mute "$DEV_DEF" toggle 2>/dev/null || \
		pactl set-source-mute "$DEV_DEF" toggle
	fi
}

get_state() {
	local state
	state=$(get_mute)
	case $state in
		"yes") printf "Muted" ;;
		"no")  printf "Unmuted" ;;
	esac
}

get_icon() {
	local state level
	state=$(get_state)
	level=$(get_volume)
	local new_level=${1:-$level}

	if [[ $state == "Muted" ]]; then
		printf "%s" "$DEV_ICON-muted"
	else
		if ((new_level < MAX * 33 / 100)); then
			printf "%s" "$DEV_ICON-low"
		elif ((new_level < MAX * 66 / 100)); then
			printf "%s" "$DEV_ICON-medium"
		else
			printf "%s" "$DEV_ICON-high"
		fi
	fi
}

notify() {
	local text=$1
	local value=$2
	local icon=$(get_icon $value)
	notify-send "$DEV_NAME: $text" -h int:value:$value -i "$icon" -t 1500 \
		-h string:x-canonical-private-synchronous:volume
}

main() {
	DEVICE=$1
	ACTION=$2
	VALUE=${3:-$DEF_VALUE}

	if ((VALUE < 1)); then
		usage >&2
		return 1
	fi

	case $DEVICE in
		"input")
			DEV_DEF="@DEFAULT_AUDIO_SOURCE@"
			DEV_ICON="mic-volume"
			DEV_NAME="Microphone"
			;;
		"output")
			DEV_DEF="@DEFAULT_AUDIO_SINK@"
			DEV_ICON="audio-volume"
			DEV_NAME="Volume"
			;;
		*) usage >&2; return 1 ;;
	esac

	# Show device name in notification (e.g. USB or Bluetooth headset)
	if [[ $AUDIO_BACKEND == "wpctl" ]]; then
		local desc
		desc=$(wpctl inspect "$DEV_DEF" 2>/dev/null | awk -F'"' '/node.description/ {print $2; exit}')
		if [[ -n $desc ]]; then
			[[ $DEVICE == "input" ]] && DEV_NAME="$desc (mic)" || DEV_NAME="$desc"
		fi
	fi

	case $ACTION in
		"mute")
			set_mute
			local state
			state=$(get_state)
			notify "$state" $(get_volume)
			;;
		"raise")
			local level new_level
			level=$(get_volume)
			new_level=$((level + VALUE))
			((new_level > MAX)) && new_level=$MAX
			set_volume "$new_level"
			notify "$new_level%" "$new_level"
			;;
		"lower")
			local level new_level
			level=$(get_volume)
			new_level=$((level - VALUE))
			((new_level < MIN)) && new_level=$MIN
			set_volume "$new_level"
			notify "$new_level%" "$new_level"
			;;
		*) usage >&2; return 1 ;;
	esac
}

main "$@"
