#!/bin/bash

# Configuration
DEVICE_MACS=("d8:cb:8a:6e:f8:e7" "d8:cb:8a:99:67:e9")  #LIST OF MAC ADDRESSES
DEVICE_IPS=("192.168.1.201" "192.168.1.204") #LIST OF IP ADDRESSES
DELAY_WAKE_PING=90
# Power on devices
wake_and_ping() {
    local ip=$1
    local mac=$2
    if [ -z "$ip" ] || [ -z "$mac" ]; then
        stdbuf -oL echo "IP or MAC address is empty"
        return 1
    fi
    stdbuf -oL echo "sending first wake on lan"
    wakeonlan "$mac"
    sleep 1
    stdbuf -oL echo "sending second wake on lan"
    wakeonlan "$mac"
    stdbuf -oL echo "waiting $DELAY_WAKE_PING seconds"
    sleep $DELAY_WAKE_PING
    stdbuf -oL echo "staring ping"
    ping -c 1 "$ip"
    return $?
}


selected_ip=$1
if  [ -n "$selected_ip" ]; then
    found=0
    for index in "${!DEVICE_IPS[@]}"; do
        if [[ "${DEVICE_IPS[$index]}" == "$selected_ip" ]]; then
            selected_mac="${DEVICE_MACS[$index]}"
            found=1
            break
        fi
    done
    if [ $found -eq 1 ]; then
        stdbuf -oL echo "Found IP $selected_ip with mac $selected_mac"
        wake_and_ping "$selected_ip" "$selected_mac" || { stdbuf -oL echo "Failed to wake and ping $selected_ip"; exit 1; }
    else
        stdbuf -oL echo "IP $selected_ip not found in the list"
        exit 1
    fi
else
    stdbuf -oL echo "Powering on all devices"
    for (( i=0; i < "${#DEVICE_MACS[@]}"; i++ )); do
        MAC="${DEVICE_MACS[$i]}"
        IP="${DEVICE_IPS[$i]}"
        wake_and_ping "$IP" "$MAC" || stdbuf -oL echo "Failed to wake and ping $IP" 
    done
fi