.. meta::
   :keywords:
      GPU passthrough, VFIO-PCI, OpenShift, Kubevirt, SNO, Nvidia, Windows VM::
   :description:
      how to run OpenShift as a workstation with GPU PCI passthrough 
      and Container Native Virtualization (CNV) to provide a virtualized desktop 
      experience on a single OpenShift node (SNO). 


*******************************************************************
Setting up a virtual workstation in OpenShift with VFIO passthrough
*******************************************************************

.. article-info::
    :date: Feb 27, 2023
    :read-time: 25 min read

Introduction
============

This article provides a detailed guide on how to configure OpenShift as a workstation 
with GPU PCI passthrough and Container Native Virtualization (CNV) on a single OpenShift 
node (SNO). 

This setup allows you to leverage Kubernetes orchestration capabilities 
while still enjoying near-native performance for GPU-intensive applications.

**Why this approach?**

* Run both containerized workloads and virtual machines on the same hardware
* Use a single GPU for both Kubernetes pods and virtual machines by switching the driver binding
* Achieve near-native performance for gaming and professional applications in VMs
* Maintain the flexibility and power of Kubernetes/OpenShift for other workloads

In testing, this configuration successfully ran Microsoft Flight Simulator in a Windows VM 
with performance smiliar to a bare metal Windows installation. 


Hardware description
--------------------

The workstation used for this demo has the following hardware:

- **CPU**: AMD Ryzen 9 3950X 16-Core 32-Threads
- **Memory**: 64GB DDR4 3200MHz
- **GPU**: Nvidia RTX 3080 FE 10GB
- **Storage**:
  - 2x 2TB NVMe Disks (for virtual machine storage)
  - 1x 500GB SSD Disk (for OpenShift root system)
- **Network**: 10Gbase-CX4 Mellanox Ethernet

Similar configurations with equivalent Intel CPUs should work with minor adjustments noted throughout the guide.


Backup of existing system partitions
-------------------------------------

To avoid boot order conflicts, the OpenShift assisted installer will format the first 
512 bytes of any disks that contain a bootable partition. Therefore, it is important to 
backup and remove any existing partition table that you would like to preserve.

.. seealso::

   https://github.com/openshift/assisted-service/blob/d37ac44051be76e95676f33b8361c04eae290357/internal/host/hostcommands/install_cmd.go#L232
  

Installing OpenShift SNO
========================

Before proceeding with the installation, ensure you've completed the backup steps for any existing partitions.

.. seealso::

   https://docs.openshift.com/container-platform/4.12/installing/installing_sno/install-sno-installing-sno.html


Once any existing file system is backed up and there are no more bootable
partitions, we can proceed with the OpenShift Single Node installation.

It is important to note that CoreOS, the underlying operating system, requires an
entire disk for installation. For this workstation setup:

1. We'll use the 500GB SSD disk for the OpenShift operating system
2. The two 2TB NVMe disks will be reserved for persistent volumes as LVM Physical
   volumes belonging to the same Volume Group
3. This configuration allows for flexible VM storage management while keeping the
   system installation separate


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


Installing and configuring the NVIDIA GPU Operator
---------------------------------------------------

The NVIDIA GPU Operator automates the management of NVIDIA GPUs in Kubernetes environments.

Step 1: Install the GPU Operator
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

1. Navigate to the OpenShift web console
2. Go to **Operators** → **OperatorHub**
3. Search for "NVIDIA GPU Operator"
4. Select the operator and click **Install**
5. Keep the default installation settings and click **Install** again

Alternatively, you can install it through the CLI using the following commands:

.. code-block:: bash

    oc create -f https://raw.githubusercontent.com/NVIDIA/gpu-operator/master/deployments/git/operator-namespace.yaml
    oc create -f https://raw.githubusercontent.com/NVIDIA/gpu-operator/master/deployments/git/operator-source.yaml

Step 2: Configure the ClusterPolicy
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

When deploying the operator's ClusterPolicy, we need to set ``sandboxWorkloads.enabled`` 
to ``true`` to enable the sandbox-device-plugin and vfio-manager components, which are essential for GPU passthrough.


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


As the Nvidia GPU Operator does not officialy supports consumer grade GPUs it does not take the
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


Dynamically Switching GPU Drivers
-------------------------------------

One of the key advantages of this setup is the ability to use a single GPU for both container 
workloads and virtual machines without rebooting the system.

Use Case Scenario
~~~~~~~~~~~~~~~~~

* Our workstation has a single NVIDIA GPU
* Container workloads (such as AI/ML applications) require the NVIDIA kernel driver
* Virtual machines with GPU passthrough require the VFIO-PCI driver
* We need to switch between these modes without system reboots

Driver Switching Using Node Labels
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

The NVIDIA GPU Operator with sandbox workloads enabled provides a convenient way to switch 
driver bindings using node labels:

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

* The driver switching process takes a few minutes to complete
* You can verify the current driver binding with ``lspci -nnk | grep -A3 NVIDIA``
* All GPU workloads must be stopped before switching drivers
* No system reboot isually required for the switch to take effect
* This have prouved to be a bit unreliable and may require a reboot


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



Passthrough USB Host Controllers to the VM
===============================================

For a complete desktop experience, you'll want to connect input devices (mouse, keyboard) 
and audio devices directly to your virtual machine. Instead of passthrough individual 
USB devices, we'll passthrough an entire USB controller to the VM for better performance 
and flexibility.

Step 1: Identify a Suitable USB Controller
---------------------------------------------

First, we need to identify an appropriate USB controller that we can dedicate to the virtual machine:

.. seealso::

    https://docs.openshift.com/container-platform/4.12/virt/virtual_machines/advanced_vm_management/virt-configuring-pci-passthrough.html

1. List all PCI devices on your system:

    .. code-block:: bash
   
       lspci -nnk | grep -i usb

   Example output:
   ```
   0b:00.3 USB controller [0c03]: Advanced Micro Devices, Inc. [AMD] Matisse USB 3.0 Host Controller [1022:149c]
   ```

2. Note the PCI address (e.g., `0b:00.3`) and the device ID (`1022:149c` in the example).

3. Verify the IOMMU group of the controller to ensure it can be safely passed through:

   .. code-block:: bash
   
       find /sys/kernel/iommu_groups/ -iname "*0b:00.3*"
       # Shows which IOMMU group contains this device
       
       ls /sys/kernel/iommu_groups/27/devices/
       # Lists all devices in the same IOMMU group

4. **Important**: For clean passthrough, the USB controller should ideally be alone in its IOMMU group. If other devices are in the same group, you'll need to pass those through as well.


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


Creating a Virtual Machine with GPU Passthrough
===============================================

This section guides you through creating virtual machines that can utilize the GPU via PCI passthrough. We'll use existing LVM Logical Volumes where the operating system is already installed with UEFI boot.

Step 1: Create Persistent Volumes from LVM Disks
-------------------------------------------------------

First, we need to make our LVM volumes available to OpenShift by creating a Persistent Volume Claims (PVCs).
This assume you have the Local Storage Operator installed and running.

.. seealso::

   https://docs.redhat.com/en/documentation/openshift_container_platform/4.12/html/storage/configuring-persistent-storage#lvms-installing-lvms-with-web-console_logical-volume-manager-storage


1. Create a YAML file for each VM disk. Here's an example for a Fedora 35 VM:

.. literalinclude:: /articles/openshift-workstation/pv/fedora35.yaml
    :language: yaml
    :linenos:
    :caption: fedora_pvc.yaml

2. Apply the YAML to create the PV and PVC:

.. code-block:: bash

    oc apply -f fedora35.yaml

3. Verify the PV and PVC are created and bound:

.. code-block:: bash

    oc get pv
    oc get pvc -n <your-namespace>


Step 2: Defining the Virtual Machine with GPU Passthrough
----------------------------------------------------------

When creating virtual machines for desktop use with GPU passthrough, several important configurations need to be applied:

Key Configuration Elements
~~~~~~~~~~~~~~~~~~~~~~~~~~

1. **GPU Passthrough**: Pass the entire physical GPU to the VM
   
   .. seealso::
      https://kubevirt.io/user-guide/virtual_machines/host-devices/#pci-passthrough

2. **Disable Virtual VGA**: Remove the default emulated VGA device since we're using the physical GPU
   
   .. seealso::
      https://kubevirt.io/api-reference/master/definitions.html#_v1_devices

3. **USB Controller Passthrough**: Include the USB controller for connecting peripherals directly
   
4. **UEFI Boot**: Use UEFI boot mode for compatibility with modern operating systems and GPU drivers
   
   .. seealso::
      https://docs.openshift.com/container-platform/4.12/virt/virtual_machines/advanced_vm_management/virt-efi-mode-for-vms.html

5. **CPU/Memory Configuration**: Allocate appropriate resources based on workload requirements
    

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


Troubleshooting
===============

This section covers common issues you might encounter when setting up GPU passthrough with OpenShift and their solutions.

IOMMU Group Viability Issues
----------------------------

**Problem:**
Virtual machine fails to start with an error similar to:

.. code-block:: bash

    {"component":"virt-launcher","level":"error","msg":"Failed to start VirtualMachineInstance",
    "reason":"virError... vfio 0000:07:00.1: group 19 is not viable
    Please ensure all devices within the iommu_group are bound to their vfio bus driver."}

**Diagnosis:**
This error occurs when not all devices in the same IOMMU group are bound to the vfio-pci driver. To check the IOMMU group:

.. code-block:: bash

    # Check which devices are in the same IOMMU group
    ls /sys/kernel/iommu_groups/19/devices/
    # Output shows multiple devices in the group:
    # 0000:03:08.0  0000:07:00.0  0000:07:00.1  0000:07:00.3
    
    # Check what one of these devices is
    lspci -nnks 07:00.0
    # Output: AMD Starship/Matisse Reserved SPP [1022:1485]

**Solution:**
All devices in the same IOMMU group need to be bound to the vfio-pci driver. Modify your vfio-prepare.sh script to include all devices in the IOMMU group:

.. code-block:: bash

    # Add these lines to your vfio-prepare.sh script
    echo "vfio-pci" > /sys/bus/pci/devices/0000:03:08.0/driver_override
    echo "vfio-pci" > /sys/bus/pci/devices/0000:07:00.0/driver_override
    echo "vfio-pci" > /sys/bus/pci/devices/0000:07:00.1/driver_override
    echo "vfio-pci" > /sys/bus/pci/devices/0000:07:00.3/driver_override
    
    # Make sure to unbind from current drivers first and then bind to vfio-pci
    # as shown in the vfio-prepare.sh script example

Other Common Issues
-------------------

**No display output after GPU passthrough:**

* Ensure you've disabled the virtual VGA device in the VM specification
* Check that you've passed through both the GPU and its audio device
* Install the appropriate GPU drivers inside the virtual machine

**Performance issues in Windows VM:**

* Ensure CPU pinning is configured correctly
* Consider enabling huge pages for memory performance
* Install the latest NVIDIA drivers from within the VM
* Disable the Windows Game Bar and other overlay software

**GPU driver switching fails:**

* Verify all GPU workloads are stopped before switching
* Check the GPU operator pod logs: ``oc logs -n nvidia-gpu-operator <pod-name>``
* Verify IOMMU is properly enabled in BIOS/UEFI settings

For more troubleshooting help, check the logs of the following components:

* virt-handler: ``oc logs -n openshift-cnv virt-handler-<hash>``
* virt-launcher: ``oc logs -n <namespace> virt-launcher-<vm-name>-<hash>``
* nvidia-driver-daemonset: ``oc logs -n nvidia-gpu-operator nvidia-driver-daemonset-<hash>``
