


oc label node da2 --overwrite nvidia.com/gpu.workload.config=container
oc label node da2 --overwrite nvidia.com/gpu.workload.config=vm-passthrough


# 05:00.0 Network controller [0280]: Intel Corporation Wi-Fi 6 AX200 [8086:2723] (rev 1a)
# 	Subsystem: Intel Corporation Wi-Fi 6 AX200NGW [8086:0084]
# 
# 07:00.1 USB controller [0c03]: Advanced Micro Devices, Inc. [AMD] Matisse USB 3.0 Host Controller [1022:149c]
# 	Subsystem: ASUSTeK Computer Inc. Device [1043:87c0]
# 
# 07:00.3 USB controller [0c03]: Advanced Micro Devices, Inc. [AMD] Matisse USB 3.0 Host Controller [1022:149c]
# 	Subsystem: Advanced Micro Devices, Inc. [AMD] Device [1022:148c]
# 
# 0a:00.0 VGA compatible controller [0300]: NVIDIA Corporation GA102 [GeForce RTX 3080] [10de:2206] (rev a1)
# 	Subsystem: NVIDIA Corporation GA102 [GeForce RTX 3080] [10de:1467]
# 
# 0a:00.1 Audio device [0403]: NVIDIA Corporation GA102 High Definition Audio Controller [10de:1aef] (rev a1)
# 	Subsystem: NVIDIA Corporation Device [10de:1467]
# 
# 0c:00.3 USB controller [0c03]: Advanced Micro Devices, Inc. [AMD] Matisse USB 3.0 Host Controller [1022:149c]
# 	Subsystem: ASUSTeK Computer Inc. Device [1043:87c0]
# 
# 0c:00.4 Audio device [0403]: Advanced Micro Devices, Inc. [AMD] Starship/Matisse HD Audio Controller [1022:1487]
# 	Subsystem: ASUSTeK Computer Inc. Device [1043:87c6]


oc label node/da2 --overwrite nvidia.com/gpu.deploy.dcgm=false nvidia.com/gpu.deploy.driver=false nvidia.com/gpu.deploy.gpu-feature-discovery=false nvidia.com/gpu.deploy.container-toolkit=false nvidia.com/gpu.deploy.device-plugin=false nvidia.com/gpu.deploy.operator-validator=false nvidia.com/gpu.deploy.node-status-exporter=false nvidia.com/gpu.deploy.dcgm-exporter=false

ssh da2

modprobe vfio-pci

#!/bin/bash

vfio_attach () {
  if [ -f "${path}/driver/unbind" ]; then
    echo $address > ${path}/driver/unbind
  fi
  echo vfio-pci > ${path}/driver_override
  echo $address > /sys/bus/pci/drivers/vfio-pci/bind || \
  echo $name > /sys/bus/pci/drivers/vfio-pci/new_id ||true
}

# 05:00.0 Network controller [0280]: Intel Corporation Wi-Fi 6 AX200 [8086:2723] (rev 1a)
address=0000:05:00.0
path=/sys/bus/pci/devices/0000\:05\:00.0
name="8086 0084"
vfio_attach

# 07:00.1 USB controller [0c03]: Advanced Micro Devices, Inc. [AMD] Matisse USB 3.0 Host Controller [1022:149c]
address=0000:07:00.1
path=/sys/bus/pci/devices/0000\:07\:00.1
name="1043 87c0"
vfio_attach

# 07:00.3 USB controller [0c03]: Advanced Micro Devices, Inc. [AMD] Matisse USB 3.0 Host Controller [1022:149c]
address=0000:07:00.3
path=/sys/bus/pci/devices/0000\:07\:00.3
name="1022 148c"
vfio_attach

# 0a:00.0 VGA compatible controller [0300]: NVIDIA Corporation GA102 [GeForce RTX 3080] [10de:2206] (rev a1)
address=0000:0a:00.0
path=/sys/bus/pci/devices/0000\:0a\:00.0
name="10de 1467"
vfio_attach

# 0a:00.1 Audio device [0403]: NVIDIA Corporation GA102 High Definition Audio Controller [10de:1aef] (rev a1)
address=0000:0a:00.1
path=/sys/bus/pci/devices/0000\:0a\:00.1
name="10de 1467"
vfio_attach

# 0c:00.3 USB controller [0c03]: Advanced Micro Devices, Inc. [AMD] Matisse USB 3.0 Host Controller [1022:149c]
address=0000:0c:00.3
path=/sys/bus/pci/devices/0000\:0c\:00.3
name="1022 148c"
vfio_attach

# 0c:00.4 Audio device [0403]: Advanced Micro Devices, Inc. [AMD] Starship/Matisse HD Audio Controller [1022:1487]
address=0000:0c:00.4
path=/sys/bus/pci/devices/0000\:0c\:00.4
name="1043 87c6"
vfio_attach

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