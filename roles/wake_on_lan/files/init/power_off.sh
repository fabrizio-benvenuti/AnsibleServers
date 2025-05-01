#!/bin/bash

# Configuration
DEVICE_IPS=("192.168.1.201" "192.168.1.204")  # Array of IP addresses
SSH_USERS=("server1" "server2")  # SSH username
SSH_KEY="/home/fabrizio/.ssh/id_rsa"  # Path to SSH private key
SSH_PORT=2973
POWER_OFF_COMMAND="sudo poweroff"

# Function to send SSH command
send_ssh_command() {
    local ip=$1
    local usr=$2
    local command=$3
    stdbuf -oL echo "sending $command to $usr@$ip"
    response=$(ssh -p "$SSH_PORT" -i $SSH_KEY "$usr@$ip" "$command" 2>&1)
    stdbuf -oL echo "response from host was: $response"
    if echo "$response" | grep -i "connection" | grep -i "closed by remote host"; then
	    return 0
    else
	    return 1
    fi 
}
selected_ip=$1
if  [ -n "$selected_ip" ]; then
    found=0
    for index in "${!DEVICE_IPS[@]}"; do
        if [[ "${DEVICE_IPS[$index]}" == "$selected_ip" ]]; then
            selected_user="${SSH_USERS[$index]}"
            found=1
            break
        fi
    done
    if [ $found -eq 1 ]; then
        stdbuf -oL echo "Found IP $selected_ip with user $selected_user"
        send_ssh_command "$selected_ip" "$selected_user" "$POWER_OFF_COMMAND"
    else
        stdbuf -oL echo "IP $selected_ip not found in the list"
        exit 1
    fi
else
    # Power off devices
    stdbuf -oL echo "Powering off all devices"
    for (( i=0; i < "${#DEVICE_IPS[@]}"; i++)); do
        ip="${DEVICE_IPS[$i]}"
        USER="${SSH_USERS[$i]}"
        if ping -c 10 "$ip"; then
            send_ssh_command "$ip" "$USER" "$POWER_OFF_COMMAND"
            if [ $? -eq 0 ]; then
                stdbuf -oL echo "### successfully run power off on ip $ip with user $USER ###"
            else
                stdbuf -oL echo "!!!failed to run power off on ip $ip with user $USER !!!"    
                exit 1
            fi
        else
            stdbuf -oL echo "$ip was already off"
        fi
    done
fi

