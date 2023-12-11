#!/bin/bash
# Path: articles/kubernetes-from-scratch/_common.sh
# Title: Common functions for Kubernetes from Scratch

cluster_name="kubernetesh"

mkdir -p ${cluster_name} && cd ${cluster_name}

github_latest() {
    curl --silent -w "%header{location}\n" ${1}/releases/latest |awk -F "/" '{print $NF}' |sed s/v//
}

github_download() {
    local url=${1}
    local version=${2}
    local file=${3}
    local download_url=${url}/releases/download/v${version}/${file}
    curl -L -o ${file} ${download_url}
}

# Find the main network interface dynamically
main_interface=$(ip route | awk '/default/ {print $5}' | head -1)

echo "Main interface is ${main_interface}"

# Get the IP address and subnet of the main network interface
ip_address=$(ip -4 addr show "$main_interface" | awk '/inet/ {print $2}' | cut -d'/' -f1)
subnet=$(ip -4 addr show "$main_interface" | awk '/inet/ {print $2}' | cut -d'/' -f2)
echo "IP address is ${ip_address} and subnet is ${subnet}"

# The network that is used by pods to communicate with each other
pod_network_cidr=""

# Get 

# Get the hostname
hostname=$(hostname -s)
echo "Hostname is ${hostname}"
