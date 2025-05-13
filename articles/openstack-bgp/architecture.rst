BGP Architecture in Red Hat OpenStack Platform
====================================================

Red Hat OpenStack Platform implements dynamic routing through FRR components and the OVN BGP agent. This architecture enables OpenStack deployments in pure layer-3 data centers.

Core Components
---------------

The BGP implementation consists of three key components:

1. **OVN BGP Agent**
   
   A Python daemon running in the ``ovn-controller`` container on Controller and Compute nodes that:
   
   * Monitors the OVN southbound database for VM and floating IP events
   * Notifies FRR when IP addresses need advertisement
   * Configures Linux kernel networking for external-to-OVN traffic routing
   * Manages the ``bgp-nic`` dummy interface for route advertisement
   
   The agent uses a multi-driver implementation, allowing configuration for specific infrastructure running on OVN, such as Red Hat OpenStack Platform or Red Hat OpenShift.
   
   Configuration file: ``/etc/ovn_bgp_agent/ovn_bgp_agent.conf``
   
   .. code-block:: ini

      [DEFAULT]
      debug = False
      reconcile_interval = 120
      expose_tenant_networks = False
      
      [bgp]
      bgp_speaker_driver = ovn_bgp_driver

2. **FRR Container Suite**

   Runs as a container on all OpenStack nodes with these components:
   
   * **BGP Daemon (bgpd)**: Handles BGP peer connections and route advertisements. Uses capability negotiation to detect remote peer capabilities.
   * **BFD Daemon (bfdd)**: Provides fast failure detection between adjacent forwarding engines.
   * **Zebra Daemon**: Interfaces between FRR and the Linux kernel routing table.
   * **VTY Shell**: Command-line interface for configuration and monitoring.
   
   Configuration file: ``/etc/frr/frr.conf``
   
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

   Handles packet routing based on FRR information, with components configured by the OVN BGP agent:
   
   * IP Rules directing traffic to specific routing tables
   * Virtual Routing and Forwarding (VRF) for network separation
   * The ``bgp-nic`` dummy interface for route advertisement
   * Static ARP/NDP entries for OVN router gateway ports

Component Interaction Flow
--------------------------

When a new VM is created or a floating IP is assigned:

1. OVN controller updates the southbound database with new port information
2. OVN BGP agent detects the change through database monitoring
3. Agent adds the IP address to the ``bgp-nic`` dummy interface
4. Agent configures IP rules and routes to direct traffic to the OVS provider bridge
5. Zebra detects the new IP and notifies the BGP daemon
6. BGP daemon advertises the route to all peers
7. External routers update their routing tables

BGP Advertisement and Traffic Redirection
-----------------------------------------

The process of advertising network routes begins with the OVN BGP agent triggering FRR to advertise directly connected routes. When traffic arrives at the node, the agent adds:

* IP rules
* Routes
* OVS flow rules

These redirect traffic to the OVS provider bridge (``br-ex``) using the Red Hat Enterprise Linux kernel networking. The OVN BGP agent ensures IP addresses are advertised whenever they are added to the ``bgp-nic`` interface.

Network Traffic Flow
--------------------

**Incoming traffic to OpenStack VMs:**

1. External router forwards packet to the OpenStack node advertising the route
2. OpenStack node processes the packet according to configured IP rules
3. Traffic is directed to the OVS provider bridge (``br-ex``)
4. OVS flows redirect traffic to the OVN overlay
5. OVN overlay delivers the packet to the VM

**Outgoing traffic from OpenStack VMs:**

1. VM sends packet through the OVN overlay
2. OVN forwards packet to the provider bridge
3. Linux network stack processes the packet
4. Packet is routed according to kernel routing table
5. Packet exits through the appropriate physical interface

Key Configuration Parameters
----------------------------

* **FRR BGP ASN**: Autonomous System Number used by BGP (default: 65000)
* **BGP Router ID**: Unique identifier for the BGP router
* **OVN BGP Agent Driver**: Controls VM IP advertisement method (default: ovn_bgp_driver)
* **Expose Tenant Networks**: Whether to advertise tenant network IPs (default: False)
* **Maximum Paths**: Number of equal-cost paths for ECMP
* **BFD Timer**: Frequency of peer liveliness checks

These components work together to provide a robust, scalable dynamic routing solution in Red Hat OpenStack Platform environments.
