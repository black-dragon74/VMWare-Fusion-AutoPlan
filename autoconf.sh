#!/bin/bash

#
#   Code is poetry
#   Created by Nick aka black.dragon74
#

# Sanitize
# set -x
clear

# These vars will be set as we find them
defRoute=""
ipAddr=""

# Functions
function genYAML() {
    if [[ -z $defRoute || -z $ipAddr ]]; then
        echo "Fatal: YAML generator called without sufficient params"
        exit 1
    fi
    
    rm -f final.yaml temp.yaml
    ( echo "cat <<eof>final.yaml";
        cat template.yaml;
    ) >temp.yaml
    . temp.yaml 2>/dev/null
    cat final.yaml
    
    rm temp.yaml
}

echo "** VMWare Fusion autoconf by Nick aka black.dragon74 **"

# Elevate
sudo foobar &>/dev/null

echo "Getting the name of the network interface.."
defRoute="$(ip route show to default 2>/dev/null | awk '{print $5}')"

if [ ! -z $defRoute ]; then
    echo "Found default route: $defRoute"
    
    # Now we get the IP address of the interface
    ipAddr="$(ip addr show|awk -v en="$defRoute" -- '$1 == "inet" && $3 == "brd" && $7 == en  { split($2, a, "/"); print a[1]; exit;}')"
    echo "The detected IP address for $defRoute is: $ipAddr"
    
    # If unable to get the IP, bail out
    if [[ -z $ipAddr ]]; then
        echo "Unable to get the IP"
        exit 1
    fi
    
    # Now as we are ready with all the requisites it's time to finally enable the netplan
    # If there exists an cloud image, disable network conf by cloud-init
    if [[ -e /etc/etc/netplan/50-cloud-init.yaml ]]; then
        echo "Found cloud init. Need to disable that."
        sudo touch /etc/cloud/cloud.cfg.d/99-disable-network-config.cfg
        sudo echo "network: {config: disabled}" > /etc/cloud/cloud.cfg.d/99-disable-network-config.cfg
        sudo mv /etc/netplan/50-cloud-init.yaml /etc/netplan/01-netcfg.yaml
        echo "Disabled cloud-init network config and enabled netcfg"
    fi
    
    # Now we need to generate the YAML file
    sudo rm -f /etc/netplan/01-netcfg.yaml
    genYAML
    
    # Ask if we wanna install
    read -p "Install the above file? [y/n] " pAns
    case $pAns in
        [nN]* )
            echo "Okay. Aborting."
            exit 0
        ;;
    esac
    
    # Now copy the file to correct location
    echo "Netplan installed."
    sudo cp final.yaml /etc/netplan/01-netcfg.yaml
    rm final.yaml
    
    # Apply the config
    sudo netplan apply || echo "Unable to apply netplan"
    echo "Netplan applied successfully. Please reboot."
    
    # We are all done
    exit 0
else
    echo "Unable to get the default network route"
    exit 1
fi