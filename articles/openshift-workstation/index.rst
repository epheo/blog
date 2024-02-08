*************************************************
OpenShift Workstation with Single GPU passthrough
*************************************************

.. article-info::
    :date: Feb 27, 2023
    :read-time: 25 min read


Introduction
============

This article describes how to run OpenShift as a workstation with GPU PCI passthrough 
and Container Native Virtualization (CNV) to provide a virtualized desktop experience 
on a single OpenShift node. 
This is useful to provide a virtual desktop experience with a single GPU, and is used 
to run Microsoft FlightSimulator in a Windows VM with performances close from a Bare 
metal Windows installation.


Hardware description
--------------------

The workstation used for this demo has the following hardware:

- AMD Ryzen 9 3950X 16-Core 32-Threads
- 64GB DDR4 3200MHz
- Nvidia RTX 3080 FE 10GB
- 2x 2TB NVMe Disks (guests)
- 1x 500GB SSD Disk (root system)
- 10Gbase-CX4 Mellanox Ethernet


Backup of existing system partitions
------------------------------------

To avoid boot order conflicts, the OpenShift assisted installer will format the first 
512 bytes of any disks that contain a bootable partition. Therefore, it is important to 
backup and remove any existing partition table that you would like to preserve.

.. seealso::

   https://github.com/openshift/assisted-service/blob/d37ac44051be76e95676f33b8361c04eae290357/internal/host/hostcommands/install_cmd.go#L232
  


Installing OpenShift SNO
========================

.. seealso::

   https://docs.openshift.com/container-platform/4.10/installing/installing_sno/install-sno-installing-sno.html


Once any existing file system is backed up and there is no more bootable
partitions we can proceed with the OpenShift Single Node install.

It is important to note that CoreOS, the underlying operating system requires an
entire disk for installation.

Here, we will keep the two NVMe disks for the persistant volumes as LVM Physical
volumes belonging to a same Volume Group and we will use the SSD disk for the
OpenShift operating system.


.. literalinclude:: /articles/openshift-workstation/install/get-ocp-binaries.sh
    :language: bash
    :linenos:

.. literalinclude:: /articles/openshift-workstation/install/install-config.yaml
    :language: yaml
    :linenos:
    :caption: install-config.yaml


.. code-block:: bash
    :caption: Generate OpenShift Container Platform assets

    mkdir ocp && cp install-config.yaml ocp
    openshift-install --dir=ocp create single-node-ignition-config



.. code-block:: bash
    :caption: Embed the ignition data into the RHCOS ISO:

    alias coreos-installer='podman run --privileged --rm \
          -v /dev:/dev -v /run/udev:/run/udev -v $PWD:/data \
          -w /data quay.io/coreos/coreos-installer:release'
    cp ocp/bootstrap-in-place-for-live-iso.ign iso.ign
    coreos-installer iso ignition embed -fi iso.ign rhcos-live.x86_64.iso
    dd if=discovery_image_sno.iso of=/dev/usbkey status=progress


Once the ISO is copied to the USB drive, you can use the USB drive to boot your
workstation node and install OpenShift Container Platform.


Install CNV Operator
--------------------

Activate Intel VT or AMD-V hardware virtualization extensions in BIOS or UEFI.

.. seealso::

   https://docs.openshift.com/container-platform/4.10/virt/install/installing-virt-cli.html


.. literalinclude:: /articles/openshift-workstation/install/cnv-resources.yaml
    :language: yaml
    :linenos:
    :caption: cnv-resources.yaml

.. code-block:: bash

    oc apply -f cnv-resources.yaml

.. code-block:: bash
    :caption: Installing the Virtctl client on your desktop.

    subscription-manager repos --enable cnv-4.10-for-rhel-8-x86_64-rpms
    dnf install kubevirt-virtctl


  
Remove Local Storage operator (if installed)
--------------------------------------------

As we do not need to manage LVM volumes automatically we would like to avoid
automatically formating Logical Volumes once they are deleted from OpenShift.

While this could lead to data leak in a multi-tenant environment, removing the
Local Storage Operator also avoid loosing your Virtual Machine partitions once
you delete it.



Configure OpenShift for single GPU passthrough
==============================================

As our GPU is the only one attached to the node a few additional steps are
required.

We will use MachineConfig to configure our node accordingly.

All MachineConfig are applied on the master machineset because we have a single
node OpenShift. With a multi nodes cluster those would be applied to workers
instead.

.. seealso::

    https://github.com/openshift/machine-config-operator/blob/master/docs/SingleNodeOpenShift.md



Passing kernel arguments at boot time
-------------------------------------

Multiple Kernel arguments have to be passed at boot time in order to configure our node 
for GPU passthrough. 
This can be done using the MachineConfigOperator. 


- **amd_iommu=on**: Enables IOMMU (Input/Output Memory Management Unit) support for AMD 
  platforms, allowing for direct memory access (DMA) by PCI devices without going 
  through the CPU. This improves performance and reduces overhead.
- **vga=off**: Disables VGA (Video Graphics Array) console output during boot time. 
- **rdblaclist=nouveau**: Enables the blacklisting of the Nouveau open-source NVIDIA 
  driver.
- **video=efifb:off**: Disables the EFI (Extensible Firmware Interface) framebuffer 
  console output during boot time. 

.. seealso::

    https://www.reddit.com/r/VFIO/comments/cktnhv/bar_0_cant_reserve/
    https://www.reddit.com/r/VFIO/comments/mx5td8/bar_3_cant_reserve_mem_0xc00000000xc1ffffff_64bit/

    https://docs.kernel.org/fb/fbcon.html


.. literalinclude:: /articles/openshift-workstation/machineconfig/build/vfio-prepare.bu
    :language: yaml
    :lines: 1-6,41-46
    :linenos:
    :caption: Setting Kernel Arguments at boot time.


.. code-block:: bash
    :linenos:

    cd articles/openshift-workstation/machineconfig/build
    butane -d . vfio-prepare.bu -o ../vfio-prepare.yaml
    oc patch MachineConfig 100-vfio --type=merge -p ../vfio-prepare.yaml

.. note::

    If you're using an Intel CPU you'll have to set intel_iommu=on instead.


Installing and configuring the NVidia GPU Operator
---------------------------------------------------

Install the GPU Operator using OLM / OpenShift Marketplace.

When deploying the operator's ClusterPolicy we have to set ``sandboxWorkloads.enabled`` 
to ``true`` to enable the sandbox-device-plugin and vfio-manager.


.. code-block:: yaml
    :linenos:
    :caption: sandboxWorkloadsEnabled.yaml

    kind: ClusterPolicy
    metadata:
      name: gpu-cluster-policy
    spec:
      sandboxWorkloads:
        defaultWorkload: container
        enabled: true

.. code-block:: bash

    oc patch ClusterPolicy gpu-cluster-policy --type=merge -p sandboxWorkloadsEnabled.yaml


As the Nvidia GPU Operator does not supports consumer grade GPUs it does not take the
audio device into consideration and therefore doesn't bind it to vfiopci driver.
This has to be done manually but can be achieved once at boot time using the following 
machine config.


.. literalinclude:: /articles/openshift-workstation/machineconfig/build/vfio-prepare.bu
    :language: yaml
    :lines: 1-6,7-18,25-40
    :linenos:
    :caption: vfio-prepare.bu


.. literalinclude:: /articles/openshift-workstation/machineconfig/build/vfio-prepare.sh
    :language: bash
    :lines: 1-16
    :linenos:
    :caption: vfio-prepare.sh


.. code-block:: bash
    :linenos:

    cd articles/openshift-workstation/machineconfig/build
    butane -d . vfio-prepare.bu -o ../vfio-prepare.yaml
    oc patch MachineConfig 100-vfio --type=merge -p ../vfio-prepare.yaml


Changing the driver binded to the GPU
-------------------------------------

- This workstation only have a single GPU.
- I'd like to use it for both Virtual Machines and AI/ML workload.
- Containers requires the GPU device to bind to the Nvidia driver.
- Virtual machines requires the GPU device to bind to the VFIO-PCI driver.
- I'd like an efficient way to bind / unbind the GPU to a driver without reboot.

We can label the node in order to configure it with the GPU bound to Nvidia kernel 
driver in order to satisky container workloads.

.. code-block:: bash

   oc label node da2 --overwrite nvidia.com/gpu.workload.config=container

Or to bind the GPU to the vfio-pci driver to satisfy Virtual Machines workloads with 
PCI passthrough.

.. code-block:: bash

   oc label node da2 --overwrite nvidia.com/gpu.workload.config=vm-passthrough

The whole operation takes a few minutes.


Add GPU as Hardware Device of your node
---------------------------------------

.. seealso::

    https://github.com/kubevirt/kubevirt/blob/main/docs/devel/host-devices-and-device-plugins.md


We indentify the Vendor and Product ID of the GPU

.. code-block:: bash

    lspci -nnk |grep VGA

We indentify the device name provided by the gpu-feature-discovery.

.. code-block:: bash

    oc get nodes da2 -ojson |jq .status.capacity |grep nvidia

.. code-block:: yaml
    :linenos:

    kind: HyperConverged
    metadata:
      name: kubevirt-hyperconverged
      namespace: openshift-cnv
    spec:
      permittedHostDevices:
        pciHostDevices:
        - externalResourceProvider: true
          pciDeviceSelector: 10DE:2206
          resourceName: nvidia.com/GA102_GEFORCE_RTX_3080

.. code-block:: bash

    oc patch hyperconverged kubevirt-hyperconverged -n openshift-cnv  --type=merge -d hyperconverged.yaml 

The `pciDeviceSelector` field specifies the vendor ID and device ID of the PCI device, 
while the `resourceName` field specifies the name of the resource that will be created 
in Kubernetes/OpenShift.



Passthrough the USB Host Controllers to the VM
===============================================

In order to directly connect a mouse, keyboard, audio device etc directly to 
the VM we passthrough one if the USB controller directly to the VM.


Identify a USB Controller and its IOMMU group
---------------------------------------------

https://docs.openshift.com/container-platform/4.8/virt/virtual_machines/advanced_vm_management/virt-configuring-pci-passthrough.html

We first need to indentify it using `pciutils`.


.. code-block:: sh

    lspci -nnk

After selecting the USB Controller we want to dedicate to the Virtual Machine we
should verify that this is the only PCI device in its IOMMU group.
We first look for the PCI address in the iommu_groups folder structure, the list
the PCI addresses belonging to this IOMMU group.


.. code-block:: sh

    find /sys/kernel/iommu_groups/ -iname "*0b:00.3*"
    ls /sys/kernel/iommu_groups/27/devices/


Add the USB Controller as Hardware Device of your node
------------------------------------------------------

.. seealso::

    https://access.redhat.com/solutions/6250271


.. seealso::

    https://kubevirt.io/user-guide/virtual_machines/host-devices/#listing-permitted-devices


Once identified we add its Vendor and product IDs to the list of permitted
Host Devices.

Currently, Kubevirt does not allow providing a specific PCI address, therefore
the pciDeviceSelector will match all similar USB Host Controller from the node.
However, as we will only bind the one we are interested in to the VFIO-PCI
driver the other ones will not be available for pci passthrough.


.. code-block:: yaml
    :linenos:

    kind: HyperConverged
    metadata:
      name: kubevirt-hyperconverged
      namespace: openshift-cnv
    spec:
      permittedHostDevices:
        pciHostDevices:
          - pciDeviceSelector: 1022:149C
            resourceName: devices.kubevirt.io/USB3_Controller
          - pciDeviceSelector: 8086:2723
            resourceName: intel.com/WIFI_Controller

.. code-block:: bash

    oc patch hyperconverged kubevirt-hyperconverged -n openshift-cnv  --type=merge -d hyperconverged.yaml 


Binding the USB Controller to VFIO-PCI driver at boot time
----------------------------------------------------------


.. literalinclude:: /articles/openshift-workstation/machineconfig/build/vfio-prepare.bu
    :language: yaml
    :linenos:
    :caption: vfio-prepare.bu

Create a bash script to unbind specific PCI devices and bind them to the VFIO-PCI 
driver.

.. literalinclude:: /articles/openshift-workstation/machineconfig/build/vfio-prepare.sh
    :language: bash
    :linenos:
    :caption: vfio-prepare.sh


.. code-block:: bash
    :linenos:

    cd articles/openshift-workstation/machineconfig/build
    butane -d . vfio-prepare.bu -o ../vfio-prepare.yaml
    oc patch MachineConfig 100-vfio --type=merge -p ../vfio-prepare.yaml


Creating a Virtual Machine
============================

The virtual machine will use existing LVM Logical volumes, here we will assume
we already have the Operating System installed on the LV with a UEFI boot.


Create PV and PV Claim out of local LVM disks
---------------------------------------------
  
Binding PV and PVC by label https://docs.openshift.com/container-platform/3.3/install_config/storage_examples/binding_pv_by_label.html

.. literalinclude:: /articles/openshift-workstation/pv/fedora35.yaml
    :language: yaml
    :linenos:
    :caption: fedora35.yaml


Defining the Virtual Machine
----------------------------

The virtual machines we will use as Desktops comes with a few specities:

- We will passthrough the entire GPU
  | Ref: https://kubevirt.io/2021/intel-vgpu-kubevirt.html
- We will remove the existing default virtual VGA
  | Ref: https://kubevirt.io/api-reference/master/definitions.html#_v1_devices
- We will passthrough an entire USB controller
- We will use UEFI boot to be closer from typical BareMetal
  | Ref: https://docs.openshift.com/container-platform/4.10/virt/virtual_machines/advanced_vm_management/virt-efi-mode-for-vms.html
    

.. literalinclude:: /articles/openshift-workstation/vms/fedora.yaml
    :language: yaml
    :linenos:
    :caption: fedora.yaml


.. literalinclude:: /articles/openshift-workstation/vms/windows.yaml
    :language: yaml
    :linenos:
    :caption: windows.yaml


Unused anymore, for reference only
==================================

Binding GPU to VFIO Driver at boot time
---------------------------------------

We first gather the PCI Vendor and product IDs from `pciutils`.

.. code-block:: bash

    lspci -nn |grep VGA


.. literalinclude:: /articles/openshift-workstation/machineconfig/100-sno-vfiopci.bu
    :caption: 100-sno-vfiopci.bu
    :language: yaml
    :linenos:


.. code-block:: bash

    dnf install butane
    butane 100-sno-vfiopci.bu -o 100-sno-vfiopci.yaml
    oc apply -f 100-sno-vfiopci.yaml

.. literalinclude:: /articles/openshift-workstation/machineconfig/98-sno-xhci-unbind.yaml
    :language: yaml
    :linenos:
    :caption: 98-sno-xhci-unbind.yaml


Unbinding VTConsole at boot time
--------------------------------

.. seealso::

    https://docs.kernel.org/fb/fbcon.html


.. literalinclude:: /articles/openshift-workstation/machineconfig/98-sno-vtconsole-unbind.yaml
    :caption: 98-sno-vtconsole-unbind.yaml
    :language: yaml
    :linenos:



What's next
===========

This chapter is kept as a reference for furture possible improvements.

- Reducing the Control Plane footprint by relaying on microshift instead.
- Using GPU from containers instead of virtual machines for Linux Desktop.


Replace node prep by qemu hooks
-------------------------------

- https://github.com/kubevirt/kubevirt/blob/main/examples/vmi-with-sidecar-hook.yaml


Enabling dedicated resources for virtual machines
-------------------------------------------------

- https://docs.openshift.com/container-platform/4.10/scalability_and_performance/using-cpu-manager.html
- https://docs.openshift.com/container-platform/4.10/virt/virtual_machines/advanced_vm_management/virt-dedicated-resources-vm.html
- https://docs.openshift.com/container-platform/4.10/virt/virtual_machines/advanced_vm_management/virt-using-huge-pages-with-vms.html


Using MicroShift and RHEL for Edge
----------------------------------

- https://microshift.io/
- https://next.redhat.com/2022/01/19/introducing-microshift/
- https://github.com/redhat-et/microshift
- https://community.ibm.com/community/user/cloud/blogs/alexei-karve/2022/03/07/microshift-11
