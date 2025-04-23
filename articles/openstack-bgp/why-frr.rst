
FRR: The Free Range Routing Suite
==================================

Free Range Routing (FRR) is the primary component powering the BGP implementation 
within Red Hat OpenStack Platform. It operates as a containerized service that seamlessly 
integrates with OVN (Open Virtual Network).

Introduction to FRR
-------------------

**Free Range Routing (FRR)** is an IP routing protocol suite of daemons that run in a container 
on all OpenStack composable roles, working together to build and maintain the routing table.

FRR originated as a fork of Quagga, aiming to overcome limitations and enhance the 
capabilities of traditional routing software. It is officially included in Red Hat Enterprise Linux (RHEL).

Key components of FRR in OpenStack include:

- **BGP daemon (``bgpd``)**: Implements BGP protocol version 4, running in the ``frr`` container 
  to handle the negotiation of capabilities with remote peers and communicate with the kernel 
  routing table through the Zebra daemon.

- **BFD daemon (``bffd``)**: Provides Bidirectional Forwarding Detection for faster failure detection 
  between adjacent forwarding engines.

- **Zebra daemon**: Coordinates information from various FRR daemons and communicates 
  routing decisions directly to the kernel routing table.

- **VTY shell (``vtysh``)**: A shell interface that aggregates CLI commands from all daemons 
  and presents them in a unified interface.


FRR Features and Capabilities in OpenStack
-------------------------------------------

FRR provides specific features that make it ideal for BGP implementation in Red Hat OpenStack Platform:

- **Equal-Cost Multi-Path Routing (ECMP)**: FRR supports ECMP for load balancing network traffic 
  across multiple paths, enhancing performance and resilience. Each protocol daemon in FRR uses 
  different methods to manage ECMP policy.
  
  Example configuration in FRR to enable ECMP with 8 paths:
  
  .. code-block:: text

     router bgp 65000
       maximum-paths 8

- **BGP Advertisement Mechanism**: FRR works with the OVN BGP agent to advertise and withdraw routes. 
  The agent exposes IP addresses of VMs and load balancers on provider networks, and optionally on 
  tenant networks when specifically configured.
  
  Example of FRR's configuration template used by the OVN BGP agent:
  
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

- **Seamless Integration with Red Hat OpenStack**: The FRR implementation in Red Hat OpenStack platform 
  uses VRF (Virtual Routing and Forwarding) named ``bgp_vrf`` and a dummy interface (``bgp-nic``) to 
  handle the redirection of traffic between external networks and the OVN overlay.


Why FRR in Red Hat OpenStack?
-----------------------------

Red Hat chose FRR for its OpenStack BGP implementation for several technical reasons:

- **OVN BGP Agent Integration**: FRR works seamlessly with the OVN BGP agent (``ovn-bgp-agent`` container), 
  which monitors the OVN southbound database for VM and floating IP events. When these events occur, 
  the agent notifies the FRR BGP daemon to advertise the associated IP addresses. This architecture 
  provides a clean separation between networking functions.
  
  Example of how OVN BGP agent interacts with FRR:
  
  .. code-block:: bash
  
      # Agent communicates with FRR through VTY shell
      $ vtysh --vty_socket -c <command_file>

- **Versatile Kernel Integration**: FRR's Zebra daemon communicates routing decisions directly to 
  the kernel routing table, allowing OpenStack to leverage Linux kernel networking capabilities for 
  traffic management. When routes need to be advertised, the agent simply adds or removes them from 
  the ``bgp-nic`` interface, and FRR handles the rest.

- **Advanced BGP Features Support**: FRR supports critical features needed in production OpenStack environments:
  - BGP graceful restart (preserves forwarding state during restarts)
  - BFD for fast failure detection (sub-second)
  - IPv4 and IPv6 address families
  - VRF support for network separation

  Example configuration for BGP graceful restart:
  
  .. code-block:: text
  
      router bgp 65000
        bgp graceful-restart
        bgp graceful-restart notification
        bgp graceful-restart restart-time 60
        bgp graceful-restart preserve-fw-state

- **Supplied with RHEL**: As FRR is included with Red Hat Enterprise Linux, it provides a consistent 
  and supported solution that integrates well with the entire Red Hat ecosystem.

