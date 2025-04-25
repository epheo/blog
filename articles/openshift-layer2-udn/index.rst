.. meta::
   :description:
      Configure and implement Layer 2 User Defined Networks (UDN) for Virtual Machines in OpenShift Virtualization to create isolated tenant networks with multi-node connectivity.
 
   :keywords:
      OpenShift, Virtualization, KubeVirt, UDN, Layer2, VM Networking, OCP, User Defined Networks, Network Isolation

.. _openshift_layer2_udn:

************************************************************
Layer 2 User Defined Networks for OpenShift Virtualization
************************************************************

.. article-info::
    :date: April 22, 2025
    :read-time: 20 min read

Configure and implement Layer 2 User Defined Networks (UDN) for Virtual Machines in OpenShift Virtualization to create isolated tenant networks with multi-node connectivity.

This use case demonstrates how to implement User Defined Networks (UDN) in OpenShift Virtualization, allowing for network isolation between Virtual Machines within a namespace or across namespaces. User Defined Networks provide a way to create isolated tenant networks for VMs, separate from the default pod network, enabling more complex network topologies and improved security isolation.

.. seealso::
   For more information about OpenShift Virtualization networking, check out the official `OpenShift Virtualization Documentation <https://docs.openshift.com/container-platform/latest/virt/virtual_machines/vm_networking/>`_.

.. note::
   This is compatible with OpenShift 4.18 and newer versions.

Implementation Steps
====================

1. Understand User Defined Networks
------------------------------------------

OpenShift Virtualization supports two types of User Defined Networks:

1. **UserDefinedNetwork (UDN)**: Provides network isolation within a single namespace.
2. **ClusterUserDefinedNetwork (Cluster UDN)**: Spans multiple namespaces, allowing VMs in different namespaces to communicate with each other while maintaining isolation from other networks.

Layer 2 vs Layer 3 User Defined Networks
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

User Defined Networks can be configured with either Layer 2 or Layer 3 topology:

.. admonition:: Layer 2 UDN
   :class: note

   * Creates a virtual switch distributed across all nodes in the cluster
   * All VMs connect to the same subnet regardless of which node they're on
   * Provides a single broadcast domain for all connected VMs
   * Supports live migration of VMs between nodes
   * Ideal for applications requiring Layer 2 adjacency or broadcast capabilities
   * Simpler to configure and manage for basic network isolation

.. admonition:: Layer 3 UDN
   :class: note

   * Creates a unique Layer 2 segment per node with Layer 3 routing between segments
   * Each node has its own subnet, with routing providing connectivity between nodes
   * Better manages broadcast traffic by containing it within node-specific segments
   * Provides improved scalability for larger deployments
   * Supports NetworkPolicy for enhanced security control
   * Recommended for environments with many VMs where broadcast traffic might be problematic

.. admonition:: Primary vs Secondary Networks
   :class: tip

   * Primary networks handle all default traffic for a pod/VM unless otherwise specified
   * Secondary networks provide additional interfaces for specific traffic types
   * A pod/VM can have only one primary network but multiple secondary networks
   * UDNs can function as either primary or secondary networks

.. important::
   **Compatibility Note:**
   
   * For Virtual Machines, only Layer 2 UDNs are supported as primary networks
   * Layer 3 UDNs are NOT supported for virtual machines and they can only be used with regular pods, not VMs

This guide focuses on Layer 2 UDNs which are commonly used for VM workloads requiring simplicity and migration capabilities.

2. Create a Namespace for User Defined Network
----------------------------------------------------

To use a User Defined Network, you must create a namespace with a specific label that enables UDN functionality:

.. literalinclude:: udn-namespace.yaml
   :language: yaml
   :caption: udn-namespace.yaml

.. important::
   The label must be applied when the namespace is created. It cannot be added to an existing namespace.

Apply the namespace configuration:

.. code-block:: bash

   oc create -f udn-namespace.yaml

3. Create a User Defined Network
-----------------------------------

Create a User Defined Network in the namespace:

.. literalinclude:: udn-example.yaml
   :language: yaml
   :caption: udn-example.yaml

Apply the UDN configuration:

.. code-block:: bash

   oc create -f udn-example.yaml

Verify that the UDN was created successfully:

.. code-block:: bash

   oc get userdefinednetwork -n udn-example

4. Create a VM on the User Defined Network
-------------------------------------------

When creating a VM in a namespace with a User Defined Network, the VM will automatically use the UDN as its primary network. The VM should be created with the default network configuration.

Example VM manifest:

.. literalinclude:: example-vm.yaml
   :language: yaml
   :caption: example-vm.yaml

.. note::
   Do not modify the network configuration for the VM. The network configuration is automatically handled by the UDN system.
   
.. important::
   After attaching a VM to a network, you must restart or live migrate the VM for the network changes to take effect:

   .. code-block:: bash
      
      # To restart the VM:
      virtctl restart example-vm
      
      # To live migrate instead (avoids downtime):
      virtctl migrate example-vm

5. Create a Cluster User Defined Network
--------------------------------------------

For communications across multiple namespaces, you can create a Cluster User Defined Network:

1. Create namespaces with appropriate labels:

   .. literalinclude:: udn-namespaces.yaml
      :language: yaml
      :caption: udn-namespaces.yaml

2. Create the Cluster User Defined Network:

   .. literalinclude:: cluster-udn-prod.yaml
      :language: yaml
      :caption: cluster-udn-prod.yaml

3. Apply the Cluster UDN configuration:

   .. code-block:: bash

      oc create -f cluster-udn-prod.yaml

4. Verify the Cluster UDN creation:

   .. code-block:: bash

      oc get clusteruserdefinednetwork

Testing and Validation
=======================

1. Test VM Connectivity within UDN
------------------------------------

1. Create multiple VMs in the same namespace with a UDN
2. Connect to the VM console or SSH:

   .. code-block:: bash

      # Connect to VM console
      virtctl console example-vm
      
      # Or use SSH if configured
      virtctl ssh example-vm

3. Verify network configuration in each VM:

   .. code-block:: bash

      # From inside VM
      ip addr show
      ip route

4. Test connectivity between VMs in the same namespace:

   .. code-block:: bash

      # From inside VM
      ping <other-vm-ip-address>

5. Verify that the VMs have received IP addresses from the UDN subnet

2. Test VM Connectivity across Cluster UDN
-------------------------------------------

1. Create VMs in different namespaces connected by a Cluster UDN
2. Verify network configuration in each VM
3. Test connectivity between VMs in different namespaces:

   .. code-block:: bash

      # From inside VM in namespace 1
      ping <vm-ip-in-namespace-2>

3. Test North/South Network Access
------------------------------------

1. Verify that VMs can access external networks:

   .. code-block:: bash

      # From inside VM
      ping 1.1.1.1

.. important::
   Even though the UDN is a Layer 2 network, don't manually configure IP addresses as UDN controller manages IP address allocation through its IPAM functionality.
