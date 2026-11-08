#!/usr/bin/env bash
#
# Interactive calendar in rofi with month/year navigation
#

# Default to current month/year
year=$(date +%Y)
month=$(date +%m)

# Navigation loop
while true; do
    # Get month name
    month_name=$(date -d "$year-$month-01" +%B)

    # Generate calendar for current month
    cal_output=$(cal -m "$month" "$year")

    # Build menu with navigation options
    menu="◀ Previous Month
▶ Next Month
▼ Previous Year
▲ Next Year
---
$cal_output"

    # Show in rofi
    selection=$(echo "$menu" | rofi \
        -dmenu \
        -config ~/.config/rofi/config.rasi \
        -theme-str 'window {width: 400; height: 500;} listview {lines: 10; scrollbar: false;}' \
        -p "$month_name $year" \
        -selected-row 4 \
        -no-custom \
        -kb-accept-entry "Return" \
        -kb-row-up "Up" \
        -kb-row-down "Down" 2>/dev/null)

    # Handle selection
    case "$selection" in
        "◀ Previous Month")
            month=$((10#$month - 1))
            if [ "$month" -eq 0 ]; then
                month=12
                year=$((year - 1))
            fi
            ;;
        "▶ Next Month")
            month=$((10#$month + 1))
            if [ "$month" -eq 13 ]; then
                month=1
                year=$((year + 1))
            fi
            ;;
        "▼ Previous Year")
            year=$((year - 1))
            ;;
        "▲ Next Year")
            year=$((year + 1))
            ;;
        "")
            # User pressed Esc - exit
            exit 0
            ;;
        *)
            # User selected a day - exit
            exit 0
            ;;
    esac
done
