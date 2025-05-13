.. meta::
   :keywords:
      GPU passthrough, VFIO-PCI, OpenShift, Kubevirt, SNO, Nvidia, Windows VM
   :description:
      How to run OpenShift as a workstation with GPU PCI passthrough 
      and Container Native Virtualization (CNV) for virtualized desktop 
      experience on a single OpenShift node (SNO).


*******************************************************************
Setting up a Virtual Workstation in OpenShift with VFIO Passthrough
*******************************************************************

.. article-info::
    :date: Feb 27, 2023
    :read-time: 25 min read

This guide explains how to configure OpenShift as a workstation with GPU PCI passthrough 
using Container Native Virtualization (CNV) on a single OpenShift node (SNO). This setup 
delivers near-native performance for GPU-intensive applications while leveraging Kubernetes 
orchestration capabilities.

**Key Benefits:**

* Run containerized workloads and virtual machines on the same hardware
* Use a single GPU for both Kubernetes pods and VMs by switching driver binding
* Achieve near-native performance for gaming and professional applications in VMs
* Maintain Kubernetes/OpenShift flexibility for other workloads

In testing, this configuration successfully ran Microsoft Flight Simulator in a Windows VM 
with performance comparable to a bare metal Windows installation.

**Hardware Used:**

.. list-table:: 
   :header-rows: 1
   :widths: 20 80

   * - Component
     - Specification
   * - **CPU**
     - AMD Ryzen 9 3950X (16-Core, 32-Threads)
   * - **Memory**
     - 64GB DDR4 3200MHz
   * - **GPU**
     - Nvidia RTX 3080 FE 10GB
   * - **Storage**
     - | 2x 2TB NVMe Disks (VM storage)
       | 1x 500GB SSD Disk (OpenShift root system)
   * - **Network**
     - 10Gbase-CX4 Mellanox Ethernet

Similar configurations with Intel CPUs should work with minor adjustments noted throughout this guide.

Installing OpenShift SNO
========================

Before installation, be sure to back up any existing partition data.

Backup Existing System Partitions
---------------------------------

The OpenShift assisted installer formats the first 512 bytes of any disk with a bootable partition. 
Back up and remove any existing partition tables you want to preserve.

.. seealso::

   https://github.com/openshift/assisted-service/blob/d37ac44051be76e95676f33b8361c04eae290357/internal/host/hostcommands/install_cmd.go#L232


OpenShift Installation
----------------------

.. seealso::

   https://docs.redhat.com/en/documentation/openshift_container_platform/latest/html/installing_on_a_single_node/install-sno-installing-sno

.. note::
   
   You can use the OpenShift web UI installer in Red Hat Hybrid Cloud Console.
   This guides you through installation with the Assisted Installer service:

   https://console.redhat.com/openshift/assisted-installer/clusters

   This also provides an automated way to install multiple Operators from Day 0.

   Relevant Operators for this setup:
    - Logical Volume Manager Storage
    - NMState
    - Node Feature Discovery
    - NVIDIA GPU
    - OpenShift Virtualization 


After backing up existing file systems and removing bootable partitions, proceed with the 
OpenShift Single Node installation.

CoreOS (the underlying operating system) requires an entire disk for installation:

1. 500GB SSD for the OpenShift operating system
2. Two 2TB NVMe disks for persistent volumes as LVM Physical volumes in the same Volume Group
3. This setup enables flexible VM storage management while keeping the system installation separate


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


After copying the ISO to a USB drive, boot your workstation from it to install OpenShift.


Installing CNV Operator
-----------------------

Enable Intel VT or AMD-V hardware virtualization extensions in your BIOS/UEFI settings.

.. seealso::

   https://docs.redhat.com/en/documentation/openshift_container_platform/latest/html/virtualization/installing


.. literalinclude:: /articles/openshift-workstation/install/cnv-resources.yaml
    :language: yaml
    :linenos:
    :caption: cnv-resources.yaml

.. code-block:: bash

    oc apply -f cnv-resources.yaml

.. code-block:: bash
    :caption: Installing Virtctl client on your desktop

    subscription-manager repos --enable cnv-4.10-for-rhel-8-x86_64-rpms
    dnf install kubevirt-virtctl


Configuring OpenShift for GPU Passthrough
=========================================

Since we're working with a single GPU, additional configuration is required.

We'll use MachineConfig to configure our node. In a single-node OpenShift setup, 
all MachineConfig changes apply to the master machineset. In multi-node clusters, 
these would apply to workers instead.

.. seealso::

    https://github.com/openshift/machine-config-operator/blob/master/docs/SingleNodeOpenShift.md


Setting Kernel Boot Arguments
-----------------------------

To enable GPU passthrough, we need to pass several kernel arguments at boot time via the MachineConfigOperator:

- **amd_iommu=on**: Enables IOMMU support for AMD platforms (use intel_iommu=on for Intel CPUs)
- **vga=off**: Disables VGA console output during boot
- **rdblaclist=nouveau**: Blacklists the Nouveau open-source NVIDIA driver
- **video=efifb:off**: Disables EFI framebuffer console output

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

    Intel CPU users: use intel_iommu=on instead of amd_iommu=on.


Installing the NVIDIA GPU Operator
----------------------------------

The NVIDIA GPU Operator simplifies GPU management in Kubernetes environments.

Step 1: Install the Operator
~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Via OpenShift web console:
1. Go to **Operators** → **OperatorHub**
2. Search for "NVIDIA GPU Operator"
3. Select the operator and click **Install**
4. Keep default settings and click **Install**

Or via CLI:

.. code-block:: bash

    oc create -f https://raw.githubusercontent.com/NVIDIA/gpu-operator/master/deployments/git/operator-namespace.yaml
    oc create -f https://raw.githubusercontent.com/NVIDIA/gpu-operator/master/deployments/git/operator-source.yaml

Step 2: Configure the ClusterPolicy
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Set ``sandboxWorkloads.enabled`` to ``true`` to enable the components needed for GPU passthrough:

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


The NVIDIA GPU Operator doesn't officially support consumer-grade GPUs and won't automatically 
bind the GPU audio device to the vfio-pci driver. We'll handle this manually with the following 
machine config:


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


Dynamically Switching GPU Drivers
---------------------------------

A key advantage of this setup is using a single GPU for both container workloads and VMs 
without rebooting.

Use Case Scenario
~~~~~~~~~~~~~~~~~

* Single NVIDIA GPU shared between container workloads and VMs
* Container workloads require the NVIDIA kernel driver
* VMs with GPU passthrough require the VFIO-PCI driver
* Switching between modes without rebooting

Driver Switching Using Node Labels
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

The NVIDIA GPU Operator with sandbox workloads enabled lets you switch driver bindings using node labels:

**For container workloads (NVIDIA driver):**

.. code-block:: bash

    # Replace 'da2' with your node name
    oc label node da2 --overwrite nvidia.com/gpu.workload.config=container

**For VM passthrough (VFIO-PCI driver):**

.. code-block:: bash

    # Replace 'da2' with your node name
    oc label node da2 --overwrite nvidia.com/gpu.workload.config=vm-passthrough

Notes on Driver Switching
~~~~~~~~~~~~~~~~~~~~~~~~~

* Driver switching takes a few minutes
* Verify current driver with ``lspci -nnk | grep -A3 NVIDIA``
* Stop all GPU workloads before switching drivers
* No reboot is usually required
* Can be occasionally unreliable and may require a reboot


Adding GPU as a Hardware Device
-------------------------------

.. seealso::

    https://github.com/kubevirt/kubevirt/blob/main/docs/devel/host-devices-and-device-plugins.md


First, identify the GPU's Vendor and Product ID:

.. code-block:: bash

    lspci -nnk |grep VGA

Then, identify the device name provided by gpu-feature-discovery:

.. code-block:: bash

    oc get nodes da2 -ojson |jq .status.capacity |grep nvidia

Now, add the GPU to the permitted host devices:

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

    oc patch hyperconverged kubevirt-hyperconverged -n openshift-cnv --type=merge -f hyperconverged.yaml 

The `pciDeviceSelector` specifies the vendor:device ID, while `resourceName` specifies the resource 
name in Kubernetes/OpenShift.


Passthrough USB Controllers to VMs
==================================

For a complete desktop experience, you'll want to pass through an entire USB controller to 
your VM for better performance and flexibility.

Identifying a Suitable USB Controller
----------------------------------------

.. seealso::

    https://docs.redhat.com/en/documentation/openshift_container_platform/latest/html-single/virtualization/index#virt-configuring-pci-passthrough


1. List all USB controllers:

   .. code-block:: bash
   
      lspci -nnk | grep -i usb

   Example output:
   ```
   0b:00.3 USB controller [0c03]: Advanced Micro Devices, Inc. [AMD] Matisse USB 3.0 Host Controller [1022:149c]
   ```

2. Note the PCI address (e.g., `0b:00.3`) and device ID (`1022:149c`).

3. Check the IOMMU group:

   .. code-block:: bash
   
       find /sys/kernel/iommu_groups/ -iname "*0b:00.3*"
       # Shows which IOMMU group contains this device
       
       ls /sys/kernel/iommu_groups/27/devices/
       # Lists all devices in the same IOMMU group

4. **Important**: For clean passthrough, the USB controller should ideally be alone in its IOMMU group. 
   If other devices share the group, you'll need to pass those through as well.


Adding the USB Controller as a Permitted Device
-----------------------------------------------

.. seealso::

    https://access.redhat.com/solutions/6250271
    https://kubevirt.io/user-guide/virtual_machines/host-devices/#listing-permitted-devices


Add the controller's Vendor and Product IDs to permitted host devices:

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

    oc patch hyperconverged kubevirt-hyperconverged -n openshift-cnv --type=merge -f hyperconverged.yaml 


Binding the USB Controller to VFIO-PCI Driver
---------------------------------------------


.. literalinclude:: /articles/openshift-workstation/machineconfig/build/vfio-prepare.bu
    :language: yaml
    :linenos:
    :caption: vfio-prepare.bu

Create a script to unbind the USB controller from its current driver and bind it to vfio-pci:

.. literalinclude:: /articles/openshift-workstation/machineconfig/build/vfio-prepare.sh
    :language: bash
    :linenos:
    :caption: vfio-prepare.sh


.. code-block:: bash
    :linenos:

    cd articles/openshift-workstation/machineconfig/build
    butane -d . vfio-prepare.bu -o ../vfio-prepare.yaml
    oc patch MachineConfig 100-vfio --type=merge -p ../vfio-prepare.yaml


Creating VMs with GPU Passthrough
=================================

This section explains how to create VMs that can use GPU passthrough, using existing 
LVM Logical Volumes with UEFI boot.

Creating Persistent Volumes from LVM Disks
------------------------------------------

First, make LVM volumes available to OpenShift via Persistent Volume Claims (PVCs).
This assumes you have the Local Storage Operator installed.

.. seealso::

   https://docs.redhat.com/en/documentation/openshift_container_platform/latest/html/storage/configuring-persistent-storage#lvms-installing-lvms-with-web-console_logical-volume-manager-storage


1. Create a YAML file for each VM disk:

.. literalinclude:: /articles/openshift-workstation/pv/fedora_pvc.yaml
    :language: yaml
    :linenos:
    :caption: fedora_pvc.yaml

2. Apply the YAML:

.. code-block:: bash

    oc apply -f fedora35.yaml

3. Verify the PV and PVC are bound:

.. code-block:: bash

    oc get pv
    oc get pvc -n <your-namespace>


Defining VMs with GPU Passthrough
-----------------------------------

Key configuration elements for desktop VMs with GPU passthrough:

1. **GPU Passthrough**: Pass the entire physical GPU to the VM
   
   .. seealso::
      https://kubevirt.io/user-guide/virtual_machines/host-devices/#pci-passthrough

2. **Disable Virtual VGA**: Remove the emulated VGA device
   
   .. seealso::
      https://kubevirt.io/api-reference/master/definitions.html#_v1_devices

3. **USB Controller Passthrough**: For connecting peripherals directly
   
4. **UEFI Boot**: For compatibility with modern OSes and GPU drivers
   
5. **CPU/Memory Configuration**: Based on workload requirements
    

.. literalinclude:: /articles/openshift-workstation/vms/fedora.yaml
    :language: yaml
    :linenos:
    :caption: fedora.yaml


.. literalinclude:: /articles/openshift-workstation/vms/windows.yaml
    :language: yaml
    :linenos:
    :caption: windows.yaml


Future Improvements
===================

Some potential future improvements to this setup:

- Using MicroShift instead of OpenShift to reduce Control Plane footprint
- Running Linux Desktop in containers instead of VMs
- Implementing more efficient resource allocation with CPU pinning and huge pages

Troubleshooting
===============

IOMMU Group Issues
------------------

**Problem:**
VM fails to start with:

.. code-block:: bash

    {"component":"virt-launcher","level":"error","msg":"Failed to start VirtualMachineInstance",
    "reason":"virError... vfio 0000:07:00.1: group 19 is not viable
    Please ensure all devices within the iommu_group are bound to their vfio bus driver."}

**Diagnosis:**
Not all devices in the IOMMU group are bound to vfio-pci. Check:

.. code-block:: bash

    # Check devices in the IOMMU group
    ls /sys/kernel/iommu_groups/19/devices/
    
    # Check what these devices are
    lspci -nnks 07:00.0

**Solution:**
Bind all devices in the IOMMU group to vfio-pci:

.. code-block:: bash

    # Add to vfio-prepare.sh
    echo "vfio-pci" > /sys/bus/pci/devices/0000:03:08.0/driver_override
    echo "vfio-pci" > /sys/bus/pci/devices/0000:07:00.0/driver_override
    echo "vfio-pci" > /sys/bus/pci/devices/0000:07:00.1/driver_override
    echo "vfio-pci" > /sys/bus/pci/devices/0000:07:00.3/driver_override
    
    # Unbind from current drivers, then bind to vfio-pci

Common Issues and Solutions
---------------------------

**No display output after GPU passthrough:**

* Disable virtual VGA in VM spec
* Pass through both GPU and audio device
* Install proper GPU drivers inside VM

**Performance issues in Windows VM:**

* Configure CPU pinning correctly
* Enable huge pages for better memory performance
* Install latest NVIDIA drivers in VM
* Disable Windows Game Bar and overlay software

**GPU driver switching fails:**

* Stop all GPU workloads before switching
* Check GPU operator logs: ``oc logs -n nvidia-gpu-operator <pod-name>``
* Verify IOMMU is enabled in BIOS/UEFI

For further troubleshooting, check logs:

* virt-handler: ``oc logs -n openshift-cnv virt-handler-<hash>``
* virt-launcher: ``oc logs -n <namespace> virt-launcher-<vm-name>-<hash>``
* nvidia-driver-daemonset: ``oc logs -n nvidia-gpu-operator nvidia-driver-daemonset-<hash>``
