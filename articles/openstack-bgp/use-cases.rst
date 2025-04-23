
Case Studies and Use Cases
==========================


Technical Implementation Scenarios
----------------------------------

Let's explore specific technical implementations of BGP in Red Hat OpenStack Platform:

- **Scenario 1: Control Plane VIP with Dynamic BGP Routing**

  In this implementation, the OVN BGP agent works with FRR to advertise control plane Virtual IP addresses 
  to external BGP peers. This architecture enables highly available OpenStack API endpoints without 
  requiring traditional L2 spanning across physical sites.
  
  Technical details:
  
  * Controllers are deployed across multiple racks in separate L3 network segments
  * Each rack has its own Top-of-Rack (ToR) switch acting as a BGP peer
  * Control plane services utilize a VIP (e.g., 192.1.1.1) that's advertised via BGP
  * FRR configuration on controllers includes:
  
  .. code-block:: text
  
      # Sample FRR configuration on an OpenStack Controller node
      router bgp 64999
        bgp router-id 172.30.1.1
        neighbor 172.30.1.254 remote-as 65000
        address-family ipv4 unicast
          network 192.1.1.1/32
        exit-address-family
  
  * The OVN BGP agent monitors for control plane events and triggers FRR to advertise the VIP
  * Pacemaker determines controller health and influences BGP route advertisements
  * BGP's fast convergence allows rapid failover when a controller becomes unavailable


.. figure:: bgp.controlplane.png
   :width: 100%
   :align: center



- **Scenario 2: Multi-Cloud Connectivity with BGP**

  BGP enables secure, efficient connectivity between multiple OpenStack clouds and external networks.
  The implementation leverages the OVN BGP agent to advertise routes to external networks.
  
  Technical implementation:
  
  * Each OpenStack cloud has its own ASN (Autonomous System Number)
  * Border nodes in each cloud run FRR with eBGP peering to external routers
  * BGP advertisements include prefixes for tenant networks that need to be accessible
  * Sample FRR configuration for external connectivity:
  
  .. code-block:: text

     # FRR configuration on border node
     router bgp 64999
       bgp router-id 10.0.0.1
       neighbor 203.0.113.1 remote-as 65001  # External peer
    address-family ipv4 unicast
      network 172.16.0.0/16  # OpenStack tenant network range
      redistribute connected
    exit-address-family
  
  * The OVN BGP agent configures kernel routing to redirect traffic to the OVN overlay:
  
  .. code-block:: bash

      # Example of IP rules added by OVN BGP agent
      $ ip rule
      0:      from all lookup local
      1000:   from all lookup [l3mdev-table]
      32000:  from all to 172.16.0.0/16 lookup br-ex  # for tenant networks
      32766:  from all lookup main
      32767:  from all lookup default

.. figure:: bgp.multicloud.png
   :width: 100%
   :align: center


- **Scenario 3: Redundancy and Loadbalancing with ECMP** 

  Red Hat OpenStack Platform implements Equal-Cost Multi-Path (ECMP) routing through FRR to provide 
  load balancing and redundancy for network traffic.
  
  Technical details:
  
  * FRR is configured to support ECMP with multiple next-hops for the same route
  * Sample ECMP configuration in FRR:
  
  .. code-block:: text

      # Enable ECMP with up to 8 paths
      router bgp 64999
        maximum-paths 8
        maximum-paths ibgp 8
  
  * BFD (Bidirectional Forwarding Detection) is enabled to detect link failures quickly:
  
  .. code-block:: text

     # BFD configuration for fast failure detection
     router bgp 64999
       neighbor 192.0.2.1 bfd
       neighbor 192.0.2.2 bfd
  
  * When network or hardware failures occur, traffic is automatically rerouted to available paths
  * The OVN BGP agent performs the following configuration to enable proper traffic flow:
  
  .. code-block:: bash

     # BGP traffic redirection components
     - Add dummy interface (bgp-nic) to VRF (bgp_vrf)
     - Add specific routes to the OVS provider bridge routing table
     - Configure ARP/NDP entries for OVN router gateway ports
     - Add OVS flows for traffic redirection

- **Scenario 4: Scaling OpenStack Infrastructure with Dynamic Advertisement**

  Red Hat OpenStack Platform uses BGP to simplify scaling by dynamically advertising routes as new 
  resources are provisioned, without manual route configuration.
  
  Technical implementation:
  
  * When new VMs or floating IPs are created, the OVN BGP agent automatically detects these changes through the OVN southbound database
  * The agent configures routing rules and triggers FRR to advertise the appropriate routes
  * Example workflow when a new VM is provisioned:
  
  .. code-block:: text
  
      1. VM is created on a Compute node with IP 172.16.5.10
      2. OVN BGP agent detects the new VM in the OVN southbound database
      3. Agent adds the IP to the bgp-nic interface:
         $ ip addr add 172.16.5.10/32 dev bgp-nic
      4. FRR's Zebra daemon detects the new IP and advertises it via BGP
      5. Agent configures traffic redirection through OVS flows:
         $ ovs-ofctl add-flow br-ex "priority=900,ip,in_port=patch-provnet-1,actions=mod_dl_dst:<bridge_mac>,NORMAL"
      6. External BGP peers receive the route and can reach the VM
  
  * For floating IPs, similar automation occurs when they're associated with instances:
  
  .. code-block:: text
  
      # OpenStack CLI command
      $ openstack floating ip create external
      # FRR automatically advertises this floating IP via BGP
      # External routers can now reach this floating IP
  
  * This dynamic nature eliminates the need to manually configure routes as the environment scales 
  