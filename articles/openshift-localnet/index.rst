.. meta::
   :description:
      How to configure OpenShift Virtualization to use localnet for direct north/south connectivity of VMs without dedicated interfaces.
 
   :keywords:
      OpenShift, Virtualization, KubeVirt, Localnet, OVN-Kubernetes, br-ex, VM Networking, OCP

.. _openshift_localnet:

**********************************************************
OpenShift Virtualization with Localnet Configuration
**********************************************************

.. article-info::
    :date: April 22, 2025
    :read-time: 15 min read

Configure OpenShift Virtualization to use localnet for direct north/south connectivity of VMs without dedicated interfaces.

This use case demonstrates how to configure OpenShift Virtualization to leverage the existing ``br-ex`` OVS bridge for direct north/south connectivity of virtual machines. Instead of using a dedicated interface, this approach reuses the main OpenShift interface to provide IP addresses from your baremetal network to your KubeVirt virtual machines.

.. seealso::
   For more information about OpenShift Virtualization networking, check out the official `OpenShift Virtualization Documentation <https://docs.openshift.com/container-platform/4.18/virt/virtual_machines/vm_networking/>`_.

.. note::
   This is compatible with OpenShift 4.18 and newer versions.

Implementation Steps
====================

1. Understanding Localnet and br-ex Bridge
------------------------------------------

The OpenShift ``br-ex`` bridge is typically used for external connectivity for the OpenShift cluster. By configuring a localnet mapping to this bridge, we can:

* Allow virtual machines to obtain IP addresses directly from the baremetal network
* Enable direct north/south connectivity without network translation
* Simplify network architecture by reusing existing resources

.. note::
   The ``br-ex`` bridge is part of OVN-Kubernetes networking in OpenShift. This approach eliminates the need for dedicated physical interfaces for VM connectivity.

2. Configure NodeNetworkConfigurationPolicy
--------------------------------------------

Create a NodeNetworkConfigurationPolicy (NNCP) to add a localnet mapping to the ``br-ex`` bridge:

.. literalinclude:: br-ex-nncp.yaml
   :language: yaml

Apply the policy:

.. code-block:: bash

   oc apply -f br-ex-nncp.yaml

3. Verify NodeNetworkConfigurationPolicy Status
-----------------------------------------------

Check that the policy has been applied correctly:

.. code-block:: bash

   oc get nncp

Expected output:

.. code-block:: text

   NAME            STATUS      REASON
   br-ex-network   Available   SuccessfullyConfigured

Verify the node network configuration enactments:

.. code-block:: bash

   oc get nnce

Expected output:

.. code-block:: text

   NAME                         STATUS      STATUS AGE   REASON
   <node-name>.br-ex-network   Available   <age>         SuccessfullyConfigured

4. Create NetworkAttachmentDefinition
---------------------------------------

Create a NetworkAttachmentDefinition (NAD) that will use the localnet:

.. literalinclude:: br-ex-network-nad.yaml
   :language: yaml

Apply the NetworkAttachmentDefinition:

.. code-block:: bash

   oc apply -f br-ex-network-nad.yaml

VLAN Configuration Example
~~~~~~~~~~~~~~~~~~~~~~~~~~

To configure a NetworkAttachmentDefinition with a specific VLAN ID, use the ``vlanID`` property in the config. This is particularly useful for environments where network segmentation is required:

.. tip::
   Using VLANs with localnet can help maintain network isolation while still leveraging the existing physical infrastructure.

.. literalinclude:: vlan-network-nad.yaml
   :language: yaml

Apply the VLAN NetworkAttachmentDefinition:

.. code-block:: bash

   oc apply -f vlan-network-nad.yaml

In this example, the virtual machines connected to this network will receive VLAN tagged traffic with VLAN ID 200.

5. Adding Network Interface to Virtual Machines
-----------------------------------------------

To attach a VM to the localnet bridge, modify your VM definition to include an additional network interface:

.. literalinclude:: example-vm.yaml
   :language: yaml

Testing and Validation
========================

1. Verify VM Network Configuration
----------------------------------

1. Connect to the VM console or SSH:

   .. code-block:: bash

      virtctl console example-vm
      # or
      virtctl ssh example-vm

2. Check network interfaces:

   .. code-block:: bash

      ip addr show

3. Verify you have two interfaces:

   * First interface connected to the pod network (``default``)
   * Second interface connected to the br-ex network with an IP from your baremetal network

2. Test External Network Connectivity
-------------------------------------

1. Test network connectivity:

   .. code-block:: bash

      # From inside VM
      ping 1.1.1.1

2. Test that external hosts can directly reach the VM on its baremetal IP:

   .. code-block:: bash

      # From an external machine
      ping <vm-ip-address>

.. important::
   VMs using localnet networking will be directly exposed to your physical network, so ensure proper security measures are in place.
