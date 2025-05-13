FRR: The Free Range Routing Suite
==================================

Free Range Routing (FRR) powers BGP implementation in Red Hat OpenStack Platform as a containerized service integrated with OVN.

What is FRR?
-------------------

**Free Range Routing (FRR)** is an IP routing protocol suite that maintains routing tables on OpenStack nodes. It forked from Quagga to overcome limitations and is officially included in Red Hat Enterprise Linux.

Key FRR components in OpenStack:

- **BGP daemon (``bgpd``)**: Implements BGP protocol v4, handling peer capabilities and communicating with the kernel through Zebra. Uses capability negotiation to detect remote peer capabilities.

- **BFD daemon (``bfdd``)**: Provides fast failure detection between adjacent forwarding engines.

- **Zebra daemon**: Coordinates routing information from various FRR daemons and updates the kernel routing table.

- **VTY shell (``vtysh``)**: Command interface that aggregates all CLI commands from the daemons and presents them in a unified interface.

FRR Features in OpenStack
--------------------------

FRR provides several critical features for OpenStack:

- **Equal-Cost Multi-Path Routing (ECMP)**: Enables load balancing across multiple paths. Each protocol daemon in FRR uses different methods to manage ECMP policy.
  
  Example configuration:
  
  .. code-block:: text

     router bgp 65000
       maximum-paths 8

- **BGP Advertisement Mechanism**: Works with OVN BGP agent to advertise IP addresses from VMs and load balancers
  
  Sample configuration template:
  
  .. code-block:: text
  
      router bgp {{ bgp_as }}
        address-family ipv4 unicast
        import vrf {{ vrf_name }}
        exit-address-family
        address-family ipv6 unicast
        import vrf {{ vrf_name }}
        exit-address-family
      router bgp {{ bgp_as }} vrf {{ vrf_name }}
        bgp router-id {{ bgp_router_id }}
        address-family ipv4 unicast
        redistribute connected
        exit-address-family

- **Integration with OpenStack**: Uses VRF (``bgp_vrf``) and a dummy interface (``bgp-nic``) to redirect traffic between external networks and OVN

Why Red Hat Chose FRR
---------------------

FRR was selected for OpenStack BGP implementation for these reasons:

- **Clean OVN Integration**: Works seamlessly with the OVN BGP agent monitoring the OVN southbound database
  
  Agent-FRR interaction:
  
  .. code-block:: bash
  
      # Agent communicates with FRR through VTY shell
      $ vtysh --vty_socket -c <command_file>

- **Direct Kernel Integration**: Zebra daemon efficiently communicates with the kernel routing table

- **Enterprise BGP Features**: Supports critical functionality:
  - BGP graceful restart for preserving forwarding state
  - BFD for sub-second failure detection
  - IPv4/IPv6 support
  - VRF for network separation

  Graceful restart configuration:
  
  .. code-block:: text
  
      router bgp 65000
        bgp graceful-restart
        bgp graceful-restart notification
        bgp graceful-restart restart-time 60
        bgp graceful-restart preserve-fw-state

- **RHEL Integration**: Included with Red Hat Enterprise Linux, providing consistent support within the Red Hat ecosystem

