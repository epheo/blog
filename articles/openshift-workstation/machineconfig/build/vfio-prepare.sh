#!/bin/bash

vfio_attach () {
  if [ -f "${path}/driver/unbind" ]; then
    echo $address > ${path}/driver/unbind
  fi
  echo vfio-pci > ${path}/driver_override
  echo $address > /sys/bus/pci/drivers/vfio-pci/bind || \
  echo $name > /sys/bus/pci/drivers/vfio-pci/new_id ||true
}

# 0a:00.1 Audio device [0403]: NVIDIA Corporation GA102 High Definition Audio Controller [10de:1aef] (rev a1)
address=0000:0a:00.1
path=/sys/bus/pci/devices/0000\:0a\:00.1
name="10de 1467"
vfio_attach

# Bind "useless" device to vfio-pci to satisfy IOMMU group
address=0000:07:00.0
path=/sys/bus/pci/devices/0000\:07\:00.0
name="1043 87c0"
vfio_attach

# Unbind USB switch and handle via vfio-pci kernel driver
address=0000:07:00.1
path=/sys/bus/pci/devices/0000\:07\:00.1
name="1043 87c0"
vfio_attach

# Unbind USB switch and handle via vfio-pci kernel driver
address=0000:07:00.3
path=/sys/bus/pci/devices/0000\:07\:00.3
name="1022 149c"
vfio_attach

# Unbind USB switch and handle via vfio-pci kernel driver
address=0000:0c:00.3
path=/sys/bus/pci/devices/0000\:0c\:00.3
name="1022 148c"
vfio_attach
