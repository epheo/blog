


#!/bin/bash
# filepath: /home/epheo/dev/blog/articles/tools/nvidia-to-vfio-pci.sh
#
# Script to configure Nvidia GPU for VM passthrough using VFIO PCI
# Configures OpenShift node labels and binds PCI devices to VFIO driver
#
# Usage: ./nvidia-to-vfio-pci.sh [nodename]

# Exit on error, undefined variable reference, and prevent errors in pipelines from being masked
set -euo pipefail

# Default values
NODE_NAME="da2"
REMOTE_EXEC=true
PCI_DEVICES=(
    # Device                  Address          Path                           Vendor ID
    # Network controller: Intel Wi-Fi 6 AX200
    "0000:05:00.0:/sys/bus/pci/devices/0000\:05\:00.0:8086 0084"
    # USB controller: AMD Matisse
    "0000:07:00.1:/sys/bus/pci/devices/0000\:07\:00.1:1043 87c0"
    # USB controller: AMD Matisse
    "0000:07:00.3:/sys/bus/pci/devices/0000\:07\:00.3:1022 148c"
    # VGA compatible controller: NVIDIA RTX 3080
    "0000:0a:00.0:/sys/bus/pci/devices/0000\:0a\:00.0:10de 1467"
    # Audio device: NVIDIA GA102 HD Audio
    "0000:0a:00.1:/sys/bus/pci/devices/0000\:0a\:00.1:10de 1467"
    # USB controller: AMD Matisse
    "0000:0c:00.3:/sys/bus/pci/devices/0000\:0c\:00.3:1022 148c"
    # Audio device: AMD Starship/Matisse
    "0000:0c:00.4:/sys/bus/pci/devices/0000\:0c\:00.4:1043 87c6"
)

# Parse command line arguments
if [ $# -eq 1 ]; then
    NODE_NAME="$1"
fi

# Display configuration information
echo "============================================"
echo "NVIDIA to VFIO PCI Configuration"
echo "============================================"
echo "Target node: $NODE_NAME"
echo "Devices to be attached to VFIO PCI:"
for device in "${PCI_DEVICES[@]}"; do
    IFS=':' read -r address path vendor_id <<< "$device"
    echo "  - $address (Vendor/Device ID: $vendor_id)"
done
echo "============================================"

# Function to configure OpenShift node for VM passthrough
configure_node_labels() {
    local node="$1"
    echo "Configuring OpenShift node labels for $node..."
    
    # Set workload config to VM passthrough
    echo "Setting workload config to VM passthrough..."
    oc label node "$node" --overwrite nvidia.com/gpu.workload.config=vm-passthrough
    
    # Disable NVIDIA GPU components
    echo "Disabling NVIDIA GPU container components..."
    oc label node/"$node" --overwrite \
        nvidia.com/gpu.deploy.dcgm=false \
        nvidia.com/gpu.deploy.driver=false \
        nvidia.com/gpu.deploy.gpu-feature-discovery=false \
        nvidia.com/gpu.deploy.container-toolkit=false \
        nvidia.com/gpu.deploy.device-plugin=false \
        nvidia.com/gpu.deploy.operator-validator=false \
        nvidia.com/gpu.deploy.node-status-exporter=false \
        nvidia.com/gpu.deploy.dcgm-exporter=false
    
    echo "Enabling VFIO PCI components..."
    oc label node/"$node" --overwrite \
        nvidia.com/gpu.deploy.gpu-feature-discovery=true \
        nvidia.com/gpu.deploy.node-status-exporter=true \
        nvidia.com/gpu.deploy.sandbox-device-plugin=true \
        nvidia.com/gpu.deploy.sandbox-validator=true \
        nvidia.com/gpu.deploy.vfio-manager=true
    
    echo "OpenShift node configuration complete."
}

# Function to create remote script for VFIO attachment
create_vfio_script() {
    cat << 'EOF'
#!/bin/bash
set -e

# Load VFIO PCI module
if ! lsmod | grep -q vfio_pci; then
    echo "Loading VFIO PCI module..."
    modprobe vfio-pci
fi

vfio_attach() {
    local address="$1"
    local path="$2"
    local name="$3"
    
    echo "Attaching $address to VFIO-PCI..."
    
    # Unbind from current driver if bound
    if [ -f "${path}/driver/unbind" ]; then
        echo "$address" > "${path}/driver/unbind"
    fi
    
    # Set driver override to vfio-pci
    echo "vfio-pci" > "${path}/driver_override"
    
    # Try binding to vfio-pci
    if ! echo "$address" > /sys/bus/pci/drivers/vfio-pci/bind 2>/dev/null; then
        echo "$name" > /sys/bus/pci/drivers/vfio-pci/new_id
    fi
    
    # Verify binding was successful
    if [ -L "${path}/driver" ] && [ "$(readlink "${path}/driver")" = "../../../bus/pci/drivers/vfio-pci" ]; then
        echo "  Success: $address is now bound to VFIO-PCI"
    else
        echo "  Warning: Failed to bind $address to VFIO-PCI" >&2
    fi
}

EOF

    # Add device attachment commands
    for device in "${PCI_DEVICES[@]}"; do
        IFS=':' read -r address path vendor_id <<< "$device"
        echo "vfio_attach \"$address\" \"$path\" \"$vendor_id\""
    done
    
    echo "echo 'VFIO PCI configuration complete.'"
}

# Main execution
main() {
    # Configure OpenShift node labels
    configure_node_labels "$NODE_NAME"
    
    if [ "$REMOTE_EXEC" = true ]; then
        # Create temporary script
        TEMP_SCRIPT=$(mktemp)
        create_vfio_script > "$TEMP_SCRIPT"
        chmod +x "$TEMP_SCRIPT"
        
        echo "Connecting to $NODE_NAME to configure VFIO PCI..."
        scp "$TEMP_SCRIPT" "$NODE_NAME:/tmp/vfio_setup.sh"
        ssh -t "$NODE_NAME" "sudo bash /tmp/vfio_setup.sh && rm /tmp/vfio_setup.sh"
        
        # Clean up
        rm "$TEMP_SCRIPT"
    else
        # For local execution, just output the VFIO setup script
        echo "Generating VFIO setup script..."
        create_vfio_script
    fi
    
    echo "Configuration complete."
}

# Run main function
main

---

# Node A is configured to run containers and receives the following software components:
# - NVIDIA Datacenter Driver - to install the driver
# - NVIDIA Container Toolkit - to ensure containers can properly access GPUs
# - NVIDIA Kubernetes Device Plugin - to discover and advertise GPU resources to kubelet
# - NVIDIA DCGM and DCGM Exporter - to monitor the GPU(s)
 

oc label node/da2 --overwrite \
  nvidia.com/gpu.deploy.gpu-feature-discovery=true \
  nvidia.com/gpu.deploy.operator-validator=true \
  nvidia.com/gpu.deploy.node-status-exporter=true \
  nvidia.com/gpu.deploy.driver=true \
  nvidia.com/gpu.deploy.container-toolkit=true \
  nvidia.com/gpu.deploy.device-plugin=true \
  nvidia.com/gpu.deploy.dcgm=true \
  nvidia.com/gpu.deploy.dcgm-exporter=true \
  nvidia.com/gpu.deploy.sandbox-device-plugin=false \
  nvidia.com/gpu.deploy.sandbox-validator=false \
  nvidia.com/gpu.deploy.vfio-manager=false
 
# Node B is configured to run virtual machines with Passthrough GPU and receives the 
# following software components:
# - VFIO Manager - to load vfio-pci and bind it to all GPUs on the node
# - Sandbox Device Plugin - to discover and advertise the passthrough GPUs to kubelet


oc label node/da2 --overwrite \
  nvidia.com/gpu.deploy.gpu-feature-discovery=true \
  nvidia.com/gpu.deploy.operator-validator=false \
  nvidia.com/gpu.deploy.node-status-exporter=true \
  nvidia.com/gpu.deploy.driver=false \
  nvidia.com/gpu.deploy.container-toolkit=false \
  nvidia.com/gpu.deploy.device-plugin=false \
  nvidia.com/gpu.deploy.dcgm=false \
  nvidia.com/gpu.deploy.dcgm-exporter=false \
  nvidia.com/gpu.deploy.sandbox-device-plugin=true \
  nvidia.com/gpu.deploy.sandbox-validator=true \
  nvidia.com/gpu.deploy.vfio-manager=true