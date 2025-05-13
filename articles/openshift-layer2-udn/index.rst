.. meta::
   :description:
      Set up Layer 2 User Defined Networks (UDN) for VMs in OpenShift Virtualization to create isolated networks with multi-node connectivity.
 
   :keywords:
      OpenShift, Virtualization, KubeVirt, UDN, Layer2, VM Networking, OCP, User Defined Networks, Network Isolation

.. _openshift_layer2_udn:

************************************************************
Layer 2 User Defined Networks for OpenShift Virtualization
************************************************************

.. article-info::
    :date: April 22, 2025
    :read-time: 20 min read

Learn how to set up Layer 2 User Defined Networks (UDN) for VMs in OpenShift Virtualization for isolated tenant networks with multi-node connectivity.

This guide shows how to implement UDNs in OpenShift Virtualization for network isolation between VMs within or across namespaces. UDNs create isolated tenant networks separate from the default pod network, enabling complex network layouts and better security.

.. seealso::
   Learn more about OpenShift Virtualization networking in the official `OpenShift Virtualization Documentation <https://docs.openshift.com/container-platform/latest/virt/virtual_machines/vm_networking/>`_.

.. note::
   This is compatible with OpenShift 4.18 and newer versions.

Implementation Steps
====================

1. Understand User Defined Networks
------------------------------------------

OpenShift Virtualization offers two UDN types:

1. **UserDefinedNetwork (UDN)**: Creates network isolation within a single namespace.
2. **ClusterUserDefinedNetwork (Cluster UDN)**: Spans multiple namespaces, allowing VMs in different namespaces to communicate while staying isolated from other networks.

Layer 2 vs Layer 3 User Defined Networks
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

UDNs can use either Layer 2 or Layer 3 topology:

.. admonition:: Layer 2 UDN
   :class: note

   * Creates a virtual switch across all cluster nodes
   * All VMs connect to the same subnet regardless of node location
   * Provides a single broadcast domain
   * Supports VM live migration between nodes
   * Best for apps needing Layer 2 adjacency
   * Simpler to configure

.. admonition:: Layer 3 UDN
   :class: note

   * Creates unique Layer 2 segments per node with Layer 3 routing between them
   * Each node has its own subnet
   * Controls broadcast traffic within node-specific segments
   * Better scalability for large deployments
   * Supports NetworkPolicy for security control
   * Better for environments with many VMs

.. admonition:: Primary vs Secondary Networks
   :class: tip

   * Primary networks handle default traffic
   * Secondary networks add interfaces for specific traffic
   * A VM can have one primary but multiple secondary networks
   * UDNs work as either primary or secondary networks

.. important::
   **Compatibility Note:**
   
   * Only Layer 2 UDNs work as primary networks for VMs
   * Layer 3 UDNs only work with regular pods, not VMs

This guide focuses on Layer 2 UDNs for VM workloads that need simplicity and migration support.

2. Create a Namespace for User Defined Network
----------------------------------------------------

Create a namespace with the UDN label:

.. literalinclude:: udn-namespace.yaml
   :language: yaml
   :caption: udn-namespace.yaml

.. important::
   Add this label when creating the namespace. You cannot add it to existing namespaces.

Apply the namespace:

.. code-block:: bash

   oc create -f udn-namespace.yaml

3. Create a User Defined Network
-----------------------------------

Create a UDN in your namespace:

.. literalinclude:: udn-example.yaml
   :language: yaml
   :caption: udn-example.yaml

Apply the UDN:

.. code-block:: bash

   oc create -f udn-example.yaml

Verify creation:

.. code-block:: bash

   oc get userdefinednetwork -n udn-example

4. Create a VM on the User Defined Network
-------------------------------------------

VMs in a namespace with a UDN automatically use the UDN as their primary network:

.. literalinclude:: example-vm.yaml
   :language: yaml
   :caption: example-vm.yaml

.. note::
   Don't modify the VM's network config. The UDN system handles it automatically.
   
.. important::
   Restart or live migrate the VM after network changes:

   .. code-block:: bash
      
      # Restart the VM:
      virtctl restart example-vm
      
      # Or live migrate (no downtime):
      virtctl migrate example-vm

5. Create a Cluster User Defined Network
--------------------------------------------

For cross-namespace communication, create a Cluster UDN:

1. Create namespaces with the proper labels:

   .. literalinclude:: udn-namespaces.yaml
      :language: yaml
      :caption: udn-namespaces.yaml

2. Create the Cluster UDN:

   .. literalinclude:: cluster-udn-prod.yaml
      :language: yaml
      :caption: cluster-udn-prod.yaml

3. Apply the config:

   .. code-block:: bash

      oc create -f cluster-udn-prod.yaml

4. Verify creation:

   .. code-block:: bash

      oc get clusteruserdefinednetwork

Testing and Validation
=======================

1. Test VM Connectivity within UDN
------------------------------------

1. Create multiple VMs in the same namespace with a UDN
2. Connect to the VM:

   .. code-block:: bash

      # Use console
      virtctl console example-vm
      
      # Or SSH if available
      virtctl ssh example-vm

3. Check network config:

   .. code-block:: bash

      ip addr show
      ip route

4. Test connectivity between VMs:

   .. code-block:: bash

      ping <other-vm-ip-address>

5. Verify VMs got IP addresses from the UDN subnet

2. Test VM Connectivity across Cluster UDN
-------------------------------------------

1. Create VMs in different namespaces connected by a Cluster UDN
2. Check network config in each VM
3. Test connectivity:

   .. code-block:: bash

      # From VM in namespace 1
      ping <vm-ip-in-namespace-2>

3. Test North/South Network Access
------------------------------------

1. Test external network access:

   .. code-block:: bash

      # From inside the VM
      ping 1.1.1.1

.. important::
   Don't manually configure IP addresses. The UDN controller manages IP allocation through IPAM.
