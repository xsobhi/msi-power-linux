#!/bin/bash
# Usage: battery-calibrate.sh on|off|watch
# on   = disable auto hibernate/shutdown on low battery (lets it drain to hardware cutoff)
# off  = restore normal low-battery protection
# watch = live battery readout straight from the kernel
case "$1" in
  on)
    gsettings set org.cinnamon.settings-daemon.plugins.power critical-battery-action 'nothing'
    sudo systemctl mask --now upower.service
    echo "Calibration mode ON: no auto hibernate/shutdown. Run '$0 off' when done."
    ;;
  off)
    sudo systemctl unmask upower.service
    sudo systemctl start upower.service
    gsettings set org.cinnamon.settings-daemon.plugins.power critical-battery-action 'hibernate'
    echo "Calibration mode OFF: normal battery protection restored."
    ;;
  watch)
    B=/sys/class/power_supply/BAT1
    while true; do
      printf '\r%s  %3s%%  %s/%s mAh  %s V   ' "$(cat $B/status)" "$(cat $B/capacity)" \
        $(( $(cat $B/charge_now)/1000 )) $(( $(cat $B/charge_full)/1000 )) \
        "$(awk '{printf "%.2f",$1/1e6}' $B/voltage_now)"
      sleep 5
    done
    ;;
  *) echo "Usage: $0 on|off|watch" ;;
esac
