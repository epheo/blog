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

Overview
========

This use case demonstrates how to implement User Defined Networks (UDN) in OpenShift Virtualization, allowing for network isolation between Virtual Machines within a namespace or across namespaces. User Defined Networks provide a way to create isolated tenant networks for VMs, separate from the default pod network, enabling more complex network topologies and improved security isolation.

Prerequisites
=============

* OpenShift Container Platform 4.18 or newer
* OpenShift Virtualization operator installed and configured
* OVN-Kubernetes as the cluster network provider
* Cluster administrator privileges

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

This guide focuses on Layer 2 UDNs which are commonly used for VM workloads requiring simplicity and migration capabilities.

2. Create a Namespace for User Defined Network
----------------------------------------------------

To use a User Defined Network, you must create a namespace with a specific label that enables UDN functionality:

.. code-block:: yaml

   apiVersion: v1
   kind: Namespace
   metadata:
     name: udn-example
     labels:
       k8s.ovn.org/primary-user-defined-network: ""

.. important::
   The label must be applied when the namespace is created. It cannot be added to an existing namespace.

Apply the namespace configuration:

.. code-block:: bash

   oc create -f udn-namespace.yaml

3. Create a User Defined Network
-----------------------------------

Create a User Defined Network in the namespace:

.. code-block:: yaml

   apiVersion: k8s.ovn.org/v1
   kind: UserDefinedNetwork
   metadata:
     name: udn-example
     namespace: udn-example
   spec:
     layer2:
       ipam:
         lifecycle: Persistent
       role: Primary
       subnets:
       - 10.200.0.0/16
     topology: Layer2

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

.. code-block:: yaml

   apiVersion: kubevirt.io/v1
   kind: VirtualMachine
   metadata:
     name: example-vm
     namespace: udn-example
   spec:
     running: true
     template:
       spec:
         domain:
           devices:
             disks:
             - name: rootdisk
               disk:
                 bus: virtio
             interfaces:
             - name: default
               binding:
                 name: l2bridge
           resources:
             requests:
               memory: 2Gi
         networks:
         - name: default
           pod: {}
         volumes:
         - name: rootdisk
           containerDisk:
             image: quay.io/containerdisks/fedora:latest

.. note::
   Do not modify the network configuration for the VM. The network configuration is automatically handled by the UDN system.

5. Create a Cluster User Defined Network
--------------------------------------------

For communications across multiple namespaces, you can create a Cluster User Defined Network:

1. Create namespaces with appropriate labels:

   .. code-block:: yaml

      apiVersion: v1
      kind: Namespace
      metadata:
        name: udn-prod
        labels:
          k8s.ovn.org/primary-user-defined-network: ""
          cluster-udn: prod

   .. code-block:: yaml

      apiVersion: v1
      kind: Namespace
      metadata:
        name: udn-preprod
        labels:
          k8s.ovn.org/primary-user-defined-network: ""
          cluster-udn: prod

2. Create the Cluster User Defined Network:

   .. code-block:: yaml

      apiVersion: k8s.ovn.org/v1
      kind: ClusterUserDefinedNetwork
      metadata:
        name: cluster-udn-prod
      spec:
        namespaceSelector:
          matchLabels:
            cluster-udn: prod
        network:
          layer2:
            ipam:
              lifecycle: Persistent
            role: Primary
            subnets:
            - 10.100.0.0/16
          topology: Layer2

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
2. Connect to the VMs and verify network configuration:

   .. code-block:: bash

      # From inside VM
      ip address show eth0
      ip route

3. Test connectivity between VMs in the same namespace:

   .. code-block:: bash

      # From inside VM
      ping <other-vm-ip-address>

4. Verify that the VMs have received IP addresses from the UDN subnet

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

Troubleshooting
===============

.. admonition:: VM Not Receiving IP Address
   :class: warning

   Ensure the DHCP client is enabled in the VM's network configuration.

.. admonition:: Network Connectivity Issues
   :class: warning

   * Check that the UDN or Cluster UDN has been successfully created and has status "NetworkCreated" and "NetworkAllocationSucceeded"
   * Verify that the NetworkAttachmentDefinition has been created in the namespace

.. admonition:: Cross-Namespace Communication Issues
   :class: warning

   * Ensure both namespaces are labeled correctly for the Cluster UDN
   * Verify that the namespaceSelector in the Cluster UDN correctly targets the namespaces

Best Practices
==============

Network Planning
----------------
* Plan your network CIDR ranges carefully, especially if you'll have multiple UDNs
* While overlapping CIDRs between separate UDNs won't cause conflicts (since they're isolated), it can create confusion

VM Configuration
----------------
* Always enable DHCP in the VM's operating system
* Even though the UDN is a Layer 2 network, don't manually configure IP addresses

.. important::
   Using DHCP is critical as the UDN controller manages IP address allocation through its IPAM functionality.

Namespace Management
--------------------
* Remember to create namespaces with the required labels from the beginning, as they cannot be added later
* Use descriptive labels for Cluster UDNs to make management easier

Conclusion
==========

User Defined Networks provide powerful network isolation capabilities for OpenShift Virtualization, allowing both intra-namespace and cross-namespace communication between VMs while maintaining isolation from other networks. This enables complex multi-tenant deployments with proper network segmentation and security.

The benefits include:

* Improved network isolation between tenants
* Ability to create custom subnet configurations for VM networks
* Support for cross-namespace communication via Cluster UDNs
* Automatic IP address management with persistent IP assignments

.. seealso::
   For more information about OpenShift Virtualization networking, check out the official `OpenShift Virtualization Documentation <https://docs.openshift.com/container-platform/4.18/virt/virtual_machines/vm_networking/>`_.
