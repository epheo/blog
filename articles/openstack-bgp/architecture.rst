// filepath: /home/epheo/dev/blog/articles/openstack-bgp/architecture.rst
BGP Architecture in Red Hat OpenStack Platform
====================================================

Red Hat OpenStack Platform implements dynamic routing through a layered architecture that combines FRR components with the OVN BGP agent. Understanding this architecture is essential for successfully deploying and troubleshooting BGP in your OpenStack environment.

Core Components
---------------

The BGP implementation in Red Hat OpenStack Platform consists of these key components:

1. **OVN BGP Agent**
   
   The OVN BGP agent is a Python-based daemon that runs in the ``ovn-controller`` container on all Controller and Compute nodes. The agent performs several critical functions:
   
   * Monitors the OVN southbound database for VM and floating IP events
   * Notifies the FRR BGP daemon when IP addresses need to be advertised
   * Configures the Linux kernel networking stack to route external traffic to the OVN overlay
   * Manages the ``bgp-nic`` dummy interface used for route advertisement
   
   The agent's configuration is stored in ``/etc/ovn_bgp_agent/ovn_bgp_agent.conf`` and typically includes:
   
   .. code-block:: ini

      [DEFAULT]
      debug = False
      reconcile_interval = 120
      expose_tenant_networks = False
      
      [bgp]
      bgp_speaker_driver = ovn_bgp_driver

2. **FRR Container Suite**

   FRR runs as a container (``frr``) on all OpenStack nodes and includes several daemons that work together:
   
   * **BGP Daemon (bgpd)**: Implements BGP version 4, handling peer connections and route advertisements
   * **BFD Daemon (bfdd)**: Provides fast failure detection between forwarding engines
   * **Zebra Daemon**: Acts as an interface between FRR daemons and the Linux kernel routing table
   * **VTY Shell**: Provides a command-line interface for configuration and monitoring
   
   FRR configuration is typically stored in ``/etc/frr/frr.conf`` with content such as:
   
   .. code-block:: text

      frr version 8.1
      frr defaults traditional
      hostname overcloud-controller-0
      log syslog informational
      service integrated-vtysh-config
      !
      router bgp 64999
       bgp router-id 172.30.1.1
       neighbor 172.30.1.254 remote-as 65000
       !
       address-family ipv4 unicast
        network 192.0.2.0/24
        redistribute connected
       exit-address-family
      !

3. **Linux Kernel Networking**

   The Linux kernel handles actual packet routing based on the information provided by FRR. The OVN BGP agent configures several kernel components:
   
   * **IP Rules**: Direct traffic to specific routing tables
   * **VRF (Virtual Routing and Forwarding)**: Provides network namespace separation
   * **Dummy Interface**: The ``bgp-nic`` interface is used to advertise routes
   * **ARP/NDP Entries**: Static entries for OVN router gateway ports

Component Interaction Flow
--------------------------

When a new VM is created or a floating IP is assigned, the following sequence occurs:

1. The OVN controller updates the OVN southbound database with the new port information
2. The OVN BGP agent detects the change through monitoring the database
3. The agent adds the IP address to the ``bgp-nic`` dummy interface
4. The agent configures IP rules and routes to direct traffic to the OVS provider bridge
5. Zebra detects the new IP on the interface and notifies the BGP daemon
6. The BGP daemon advertises the route to all BGP peers
7. External routers update their routing tables to reach the new IP address

Network Traffic Flow
--------------------

For incoming traffic to OpenStack VMs:

1. External router receives a packet destined for an advertised IP
2. The router forwards the packet to the OpenStack node that advertised the route
3. The OpenStack node receives the packet and processes it according to the configured IP rules
4. Traffic is directed to the OVS provider bridge (``br-ex``)
5. OVS flows redirect the traffic to the OVN overlay
6. The OVN overlay delivers the packet to the appropriate VM

For outgoing traffic from OpenStack VMs:

1. VM sends a packet to an external destination
2. The packet traverses the OVN overlay
3. OVN forwards the packet to the appropriate provider bridge
4. The packet is processed by the Linux network stack
5. The packet is routed according to the kernel routing table
6. The packet exits through the appropriate physical interface to the external network

Configurable Parameters
-------------------------

Key parameters that can be configured to customize the BGP implementation:

* **FRR BGP ASN**: The Autonomous System Number used by the BGP daemon (default: 65000)
* **BGP Router ID**: Unique identifier for the BGP router
* **OVN BGP Agent Driver**: Controls how VM IPs are advertised (default: ovn_bgp_driver)
* **Expose Tenant Networks**: Whether to advertise tenant network IPs (default: False)
* **Maximum Paths**: Number of equal-cost paths for ECMP (default varies)
* **BFD Timer**: How frequently to check peer liveliness (default varies)

These components work together to provide a robust, scalable dynamic routing solution in Red Hat OpenStack Platform environments.
