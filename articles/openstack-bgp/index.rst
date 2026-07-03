.. meta::
   :description:
      BGP Implementation in Red Hat OpenStack Services on OpenShift (RHOSO) 18.0 using FRR and OVN BGP Agent
   :keywords:
      OpenStack, RHOSO, OpenShift, BGP, FRR, ECMP, ML2/OVN, OVN BGP Agent

:Publish Date: 2024-11-20

***************************************************************
BGP Implementation in Red Hat OpenStack Services on OpenShift
***************************************************************

.. article-info::
    :date: Nov 20, 2024
    :read-time: 12 min read

*Updated July 2026: RHOCP version requirements, DVR requirement, agent driver name,
and known issues refreshed against the current RHOSO 18.0 documentation.*

.. warning::
   **Deprecation Notice**: The OVN BGP Agent was deprecated in RHOSO 18.0.10 (Feature Release 3).
   This component will be removed and replaced in a future release. An alternative BGP integration
   mechanism will be provided in a future release.

Key Components
==============

RHOSO's dynamic routing relies on four primary components working together in a distributed architecture that requires dedicated networking nodes:

OVN BGP Agent
-------------

The OVN BGP agent is a Python-based daemon running in the ``ovn_bgp_agent`` container on Compute and Networker nodes. Its primary functions include:

- **Database monitoring**: Monitors the OVN northbound database for VM and floating IP events
- **Route management**: Triggers FRR to advertise or withdraw routes based on workload lifecycle
- **Traffic redirection**: Configures Linux kernel networking for proper traffic flow
- **Interface management**: Manages the ``bgp-nic`` dummy interface for route advertisement

The agent operates by detecting changes in the OVN database and translating these into BGP routing decisions.

.. note::
   In RHOSO 18.0, BGP is deployed through ``OpenStackControlPlane`` and
   ``OpenStackDataPlaneNodeSet`` custom resources managed by the RHOSO operators.

.. code-block:: ini
   :caption: OVN BGP Agent Configuration (ovn_bgp_agent.conf)

   [DEFAULT]
   debug = False
   reconcile_interval = 120
   expose_tenant_network = False
   driver = nb_ovn_bgp_driver

FRR Container Suite
-------------------

Free Range Routing runs as the ``frr`` container on all RHOSO nodes, providing enterprise-grade routing capabilities:

- **BGP Daemon (bgpd)**: Manages BGP peer relationships and route advertisements
- **BFD Daemon (bfdd)**: Provides sub-second failure detection
- **Zebra Daemon**: Interfaces between FRR and the Linux kernel routing table
- **VTY Shell**: Command-line interface for configuration and monitoring

.. code-block:: text
   :caption: Sample FRR Configuration for RHOSO

   frr version 8.5
   frr defaults traditional
   hostname rhoso-compute-0
   log syslog informational
   service integrated-vtysh-config
   !
   router bgp 64999
    bgp router-id 172.30.1.10
    neighbor 172.30.1.254 remote-as 65000
    neighbor 172.30.1.254 bfd
    !
    address-family ipv4 unicast
     redistribute connected
     maximum-paths 8
    exit-address-family
   !

Kernel Networking Integration
-----------------------------

RHOSO leverages RHEL kernel networking features configured by the OVN BGP agent:

- **VRF (Virtual Routing and Forwarding)**: Network isolation using ``bgp_vrf``
- **IP Rules**: Direct traffic to appropriate routing tables
- **Dummy Interface**: The ``bgp-nic`` interface for route advertisement
- **OVS Integration**: Flow rules redirecting traffic to the OVN overlay

Dedicated Networking Nodes
---------------------------

RHOSO BGP deployments **require** dedicated networking nodes with specific architectural constraints:

- **Mandatory Architecture**: BGP dynamic routing cannot function without dedicated networker nodes
- **DVR Integration**: Required before RHOSO 18.0.4; since 18.0.4, dynamic routing also works without DVR
- **Traffic Gateway Role**: Networker nodes host neutron router gateways and CR-LRP (Chassis Redirect Logical Router Ports)
- **North-South Traffic**: All external traffic to tenant networks flows through networker nodes
- **BGP Advertisement**: Both compute and networker nodes run FRR and OVN BGP agent containers

.. code-block:: yaml
   :caption: Networker Node Configuration Requirements

   # OpenShift node labels for dedicated networking
   apiVersion: v1
   kind: Node
   metadata:
     name: rhoso-networker-0
     labels:
       node-role.kubernetes.io/rhoso-networker: ""
       feature.node.kubernetes.io/network-sriov.capable: "true"
   spec:
     # Networker nodes require specific networking capabilities
     # and dedicated hardware for external connectivity

**Architecture Constraints**:

- **Control Plane OVN Gateways**: Control plane nodes cannot act as data plane gateway
  nodes; dedicated Networker nodes must host the OVN gateway chassis (OSPRH-661)
- **Octavia Load Balancer**: Cannot be used with BGP dynamic routing
- **Designate DNS Service**: Unsupported in dynamic routing environments
- **BFD Limitations**: BFD did not work as expected before RHOSO 18.0.7 (fixed with nft rules)

Network Architecture
====================

RHOSO BGP Network Topology
---------------------------

.. mermaid::

   ---
   config:
     theme: neutral
   ---
   graph TB
       subgraph "External Network"
           TOR1[ToR Switch 1<br/>AS 65000]
           TOR2[ToR Switch 2<br/>AS 65000]
           EXT[External Networks<br/>192.0.2.0/24]
       end
       
       subgraph "OpenShift Cluster"
           subgraph "RHOSO Control Plane"
               CP1[Controller Pod 1<br/>172.30.1.1]
               CP2[Controller Pod 2<br/>172.30.1.2]
               CP3[Controller Pod 3<br/>172.30.1.3]
           end
           
           subgraph "RHOSO Compute Nodes"
               CN1[Compute Node 1<br/>FRR + OVN BGP Agent]
               CN2[Compute Node 2<br/>FRR + OVN BGP Agent]
               CN3[Compute Node 3<br/>FRR + OVN BGP Agent]
           end
           
           subgraph "OVN Overlay"
               VM1[VM 10.0.0.10<br/>Floating IP: 192.0.2.10]
               VM2[VM 10.0.0.20<br/>Floating IP: 192.0.2.20]
               LB[Load Balancer<br/>192.0.2.100]
           end
       end
       
       TOR1 -.->|eBGP<br/>AS 64999| CN1
       TOR1 -.->|eBGP<br/>AS 64999| CN2
       TOR2 -.->|eBGP<br/>AS 64999| CN2
       TOR2 -.->|eBGP<br/>AS 64999| CN3
       
       CN1 --> VM1
       CN2 --> VM2
       CN3 --> LB
       
       TOR1 <--> EXT
       TOR2 <--> EXT

BGP Component Interactions
---------------------------

The following diagram shows detailed interactions between all RHOSO BGP components as they operate within the OpenShift container environment:

.. mermaid::

   ---
   config:
     theme: neutral
   ---
   graph TB
       subgraph "External Infrastructure"
           PEER1[BGP Peer 1<br/>ToR Switch<br/>AS 65000]
           PEER2[BGP Peer 2<br/>ToR Switch<br/>AS 65000]
       end
       
       subgraph "OpenShift Node (Compute/Networker)"
           subgraph "Container Runtime"
               subgraph "FRR Container"
                   BGPD[BGP Daemon<br/>bgpd]
                   ZEBRA[Zebra Daemon<br/>Route Manager]
                   BFD[BFD Daemon<br/>bfdd]
                   VTY[VTY Shell<br/>vtysh]
               end
               
               subgraph "OVN BGP Agent Container"
                   AGENT[OVN BGP Agent<br/>Python Daemon]
                   DRIVER[BGP Speaker Driver<br/>ovn_bgp_driver]
               end
           end
           
           subgraph "Host Kernel"
               KRTAB[Kernel Routing Table]
               BGPNIC[bgp-nic Interface<br/>Dummy Interface]
               BRVRF[bgp_vrf<br/>VRF Instance]
               IPRULES[IP Rules & Routes]
           end
           
           subgraph "OVS Integration"
               BREX[br-ex<br/>Provider Bridge]
               FLOWS[OVS Flow Rules]
           end
           
           subgraph "OVN Database"
               OVNNB[(OVN Northbound<br/>Database)]
               OVNSB[(OVN Southbound<br/>Database)]
           end
       end
       
       %% External BGP Sessions
       PEER1 <==>|TCP 179<br/>BGP Session| BGPD
       PEER2 <==>|TCP 179<br/>BGP Session| BGPD
       
       %% Internal Component Interactions
       BGPD <--> ZEBRA
       BGPD <--> BFD
       ZEBRA <--> KRTAB
       ZEBRA <--> BGPNIC
       
       %% OVN BGP Agent Monitoring
       AGENT --> OVNNB
       AGENT --> OVNSB
       AGENT --> BGPNIC
       AGENT --> IPRULES
       AGENT --> FLOWS
       
       %% Route Advertisement Flow
       BGPNIC --> KRTAB
       KRTAB --> ZEBRA
       ZEBRA --> BGPD
       BGPD --> PEER1
       BGPD --> PEER2
       
       %% Traffic Redirection
       IPRULES --> BREX
       FLOWS --> BREX
       BRVRF --> BREX
       
       %% Configuration Management
       VTY -.-> BGPD
       VTY -.-> ZEBRA
       VTY -.-> BFD
       
       DRIVER -.-> AGENT

Traffic Flow Process
--------------------

When a VM is created or a floating IP is assigned, the following sequence occurs:

.. mermaid::

   sequenceDiagram
       participant OVN as OVN Database
       participant Agent as OVN BGP Agent
       participant FRR as FRR BGP Daemon
       participant Kernel as Linux Kernel
       participant Peer as BGP Peer
       
       OVN->>Agent: VM created with IP 192.0.2.10
       Agent->>Agent: Add IP to bgp-nic interface
       Agent->>Kernel: Configure IP rules and routes
       Agent->>Kernel: Configure OVS flows
       Kernel->>FRR: Route appears in kernel table
       FRR->>Peer: Advertise route 192.0.2.10/32
       Peer->>Peer: Update routing table
       
       Note over Agent,Kernel: Traffic redirection configured
       Note over FRR,Peer: Route convergence complete

Private Network Advertising
============================

RHOSO BGP supports advertising private tenant networks, though this feature is disabled by default due to security implications.

Tenant Network Exposure Configuration
--------------------------------------

**Default Behavior**: By default, only floating IPs and provider network IPs are advertised via BGP. Private tenant networks remain isolated within the OVN overlay.

**Enabling Tenant Network Advertisement**:

.. code-block:: ini
   :caption: OVN BGP Agent Configuration with Tenant Network Exposure

   [DEFAULT]
   debug = False
   reconcile_interval = 120
   expose_tenant_network = True
   driver = nb_ovn_bgp_driver

**Security Considerations**:

- **Network Isolation**: Enabling tenant network exposure breaks traditional OpenStack network isolation
- **Routing Policies**: External routers must implement proper filtering to maintain security boundaries
- **Non-Overlapping CIDRs**: Tenant networks must use unique, non-overlapping IP ranges
- **Access Control**: External network infrastructure must enforce tenant access policies

Traffic Flow for Tenant Networks
---------------------------------

When tenant network advertising is enabled, traffic follows a specific path through dedicated networking nodes:

.. mermaid::

   ---
   config:
     theme: neutral
   ---
   graph TD
       CLIENT[External Client<br/>203.0.113.100]
       
       TOR[ToR Switch<br/>BGP AS 65000<br/>Routes: 10.1.0.0/24]
       
       subgraph NETWORKER ["Networker Node"]
           FRR1[FRR Container<br/>BGP: AS 64999<br/>Advertises: 10.1.0.0/24]
           AGENT1[OVN BGP Agent<br/>Monitors OVN DB<br/>Configures CR-LRP]
           KERNEL1[Host Kernel<br/>IP Rules & Routes]
           BREX1[br-ex Bridge<br/>Provider Bridge]
           CRLRP1[CR-LRP Gateway<br/>10.1.0.1]
       end
       
       subgraph COMPUTE ["Compute Node - OVN Overlay"]
           LROUTER[Logical Router<br/>tenant-router-1]
           LSWITCH[Logical Switch<br/>tenant-net-1<br/>10.1.0.0/24]
           VM[Tenant VM<br/>10.1.0.10]
       end
       
       %% Main Traffic Flow (Top to Bottom)
       CLIENT -->|1. Send packet<br/>dst: 10.1.0.10| TOR
       TOR -->|2. BGP route lookup<br/>forward to networker| KERNEL1
       KERNEL1 -->|3. Apply IP rules<br/>route to br-ex| BREX1
       BREX1 -->|4. Traffic injection<br/>enter OVN overlay| CRLRP1
       CRLRP1 -->|5. L3 gateway<br/>route to logical switch| LROUTER
       LROUTER -->|6. ARP resolution<br/>L3 to L2 forwarding| LSWITCH
       LSWITCH -->|7. MAC lookup<br/>deliver packet| VM
       
       %% BGP Advertisement Flow (Dashed)
       AGENT1 -.->|Monitor tenant<br/>network events| LSWITCH
       AGENT1 -.->|Configure gateway<br/>on networker node| CRLRP1
       AGENT1 -.->|Add route to<br/>bgp-nic interface| FRR1
       FRR1 -.->|BGP UPDATE<br/>advertise 10.1.0.0/24| TOR

**Key Technical Details**:

- **CR-LRP Role**: Chassis Redirect Logical Router Ports serve as the entry point for external traffic to tenant networks
- **Networker Node Gateway**: All north-south traffic to tenant networks must traverse the networker node hosting the neutron router gateway
- **Route Advertisement**: The OVN BGP agent on networker nodes advertises neutron router gateway ports when tenant network exposure is enabled

Implementation Requirements
----------------------------

**Network Planning**:

.. code-block:: text
   :caption: Tenant Network BGP Advertisement Example

   # Tenant network configuration
   router bgp 64999
     # Advertise tenant network ranges
     address-family ipv4 unicast
       network 10.0.0.0/24    # Tenant network 1
       network 10.1.0.0/24    # Tenant network 2
       network 10.2.0.0/24    # Tenant network 3
     exit-address-family
   
   # Route filtering for security
   ip prefix-list TENANT-NETWORKS permit 10.0.0.0/8 le 24
   route-map TENANT-FILTER permit 10
     match ip address prefix-list TENANT-NETWORKS

**Operational Considerations**:

- **Network Overlap Detection**: Implement monitoring to detect and prevent CIDR overlaps
- **Route Filtering**: Configure external routers with appropriate filters to prevent route leaks
- **Multi-Tenancy**: Consider impact on tenant isolation and implement additional security measures
- **Troubleshooting Complexity**: Private network advertising increases troubleshooting complexity

Real-World Deployment Scenarios
================================

Enterprise Multi-Zone Deployment
---------------------------------

**Use Case**: Large enterprise with RHOSO deployed across multiple OpenShift clusters in different availability zones.

**Multi-Zone Network Topology**:

.. mermaid::

   ---
   config:
     theme: neutral
   ---
   graph TB
       subgraph "Enterprise WAN"
           WAN[Enterprise WAN<br/>Core Network<br/>AS 65000]
           MPLS[MPLS/VPN Backbone]
       end
       
       subgraph "Availability Zone 1 (East)"
           subgraph "Zone 1 Network Infrastructure"
               TOR1A[ToR Switch 1A<br/>AS 65001]
               TOR1B[ToR Switch 1B<br/>AS 65001]
               SPINE1[Spine Switch 1<br/>AS 65001]
           end
           
           subgraph "OpenShift Cluster 1"
               subgraph "RHOSO Control Plane 1"
                   CP1A[Controller Pod 1A]
                   CP1B[Controller Pod 1B]
               end
               
               subgraph "Networker Nodes Zone 1"
                   NN1A[Networker 1A<br/>BGP AS 64999<br/>Router-ID: 10.1.1.1]
                   NN1B[Networker 1B<br/>BGP AS 64999<br/>Router-ID: 10.1.1.2]
               end
               
               subgraph "Compute Nodes Zone 1"
                   CN1A[Compute 1A]
                   CN1B[Compute 1B]
                   CN1C[Compute 1C]
               end
           end
           
           subgraph "Workloads Zone 1"
               VIP1[Control Plane VIP<br/>203.0.113.10]
               TENANT1[Tenant Networks<br/>10.1.0.0/16]
               FIP1[Floating IPs<br/>203.0.113.100~200]
           end
       end
       
       subgraph "Availability Zone 2 (West)"
           subgraph "Zone 2 Network Infrastructure"
               TOR2A[ToR Switch 2A<br/>AS 65002]
               TOR2B[ToR Switch 2B<br/>AS 65002]
               SPINE2[Spine Switch 2<br/>AS 65002]
           end
           
           subgraph "OpenShift Cluster 2"
               subgraph "RHOSO Control Plane 2"
                   CP2A[Controller Pod 2A]
                   CP2B[Controller Pod 2B]
               end
               
               subgraph "Networker Nodes Zone 2"
                   NN2A[Networker 2A<br/>BGP AS 64998<br/>Router-ID: 10.2.1.1]
                   NN2B[Networker 2B<br/>BGP AS 64998<br/>Router-ID: 10.2.1.2]
               end
               
               subgraph "Compute Nodes Zone 2"
                   CN2A[Compute 2A]
                   CN2B[Compute 2B]
                   CN2C[Compute 2C]
               end
           end
           
           subgraph "Workloads Zone 2"
               VIP2[Control Plane VIP<br/>203.0.113.11]
               TENANT2[Tenant Networks<br/>10.2.0.0/16]
               FIP2[Floating IPs<br/>203.0.113.201~255]
           end
       end
       
       %% WAN Connectivity
       WAN <--> MPLS
       MPLS <--> SPINE1
       MPLS <--> SPINE2
       
       %% Zone 1 Internal BGP
       SPINE1 <--> TOR1A
       SPINE1 <--> TOR1B
       TOR1A -.->|eBGP| NN1A
       TOR1A -.->|eBGP| CN1A
       TOR1B -.->|eBGP| NN1B
       TOR1B -.->|eBGP| CN1B
       
       %% Zone 2 Internal BGP
       SPINE2 <--> TOR2A
       SPINE2 <--> TOR2B
       TOR2A -.->|eBGP| NN2A
       TOR2A -.->|eBGP| CN2A
       TOR2B -.->|eBGP| NN2B
       TOR2B -.->|eBGP| CN2B
       
       %% Inter-Zone BGP Peering
       NN1A -.->|iBGP via WAN| NN2A
       NN1B -.->|iBGP via WAN| NN2B
       
       %% Workload Distribution
       NN1A --> VIP1
       NN1A --> TENANT1
       NN1A --> FIP1
       
       NN2A --> VIP2
       NN2A --> TENANT2
       NN2A --> FIP2

**Technical Implementation**:

.. code-block:: text
   :caption: Multi-Zone BGP Configuration

   # Zone 1 Configuration (AS 64999)
   router bgp 64999
     bgp router-id 10.1.1.1
     
     # Local zone ToR peering (eBGP)
     neighbor 10.1.1.254 remote-as 65001
     neighbor 10.1.1.253 remote-as 65001
     
     # Inter-zone peering (iBGP confederation or eBGP)
     neighbor 10.2.1.1 remote-as 64998
     neighbor 10.2.1.1 ebgp-multihop 3
     
     address-family ipv4 unicast
       # Advertise zone-specific networks
       network 203.0.113.10/32    # Control plane VIP
       network 203.0.113.100/28   # Zone 1 floating IPs
       network 10.1.0.0/16        # Zone 1 tenant networks (if enabled)
       
       # ECMP for load balancing
       maximum-paths 4
       maximum-paths ibgp 4
       
       # Route filtering between zones
       neighbor 10.2.1.1 route-map ZONE2-IN in
       neighbor 10.2.1.1 route-map ZONE1-OUT out
     exit-address-family
   
   # Zone 2 Configuration (AS 64998) 
   router bgp 64998
     bgp router-id 10.2.1.1
     
     # Local zone ToR peering (eBGP)
     neighbor 10.2.1.254 remote-as 65002
     neighbor 10.2.1.253 remote-as 65002
     
     # Inter-zone peering
     neighbor 10.1.1.1 remote-as 64999
     neighbor 10.1.1.1 ebgp-multihop 3
     
     address-family ipv4 unicast
       # Advertise zone-specific networks
       network 203.0.113.11/32    # Control plane VIP
       network 203.0.113.201/28   # Zone 2 floating IPs  
       network 10.2.0.0/16        # Zone 2 tenant networks (if enabled)
       
       maximum-paths 4
       maximum-paths ibgp 4
     exit-address-family

**Benefits**:
- **Geographic Distribution**: Workloads distributed across multiple data centers
- **Fault Isolation**: Zone failures don't impact other zones
- **Load Distribution**: Traffic distributed based on BGP routing policies
- **Disaster Recovery**: Automatic failover between zones via BGP route withdrawal
- **Scalability**: Independent scaling of compute and network resources per zone

Control Plane High Availability
--------------------------------

**Use Case**: RHOSO control plane services distributed across OpenShift nodes with BGP-advertised VIPs.

.. mermaid::

   ---
   config:
     theme: neutral
   ---
   graph LR
       subgraph "OpenShift Cluster"
           CP1[Control Plane Pod 1<br/>Node: ocp-master-1]
           CP2[Control Plane Pod 2<br/>Node: ocp-master-2]
           CP3[Control Plane Pod 3<br/>Node: ocp-master-3]
           VIP[Control Plane VIP<br/>192.0.2.100]
       end
       
       subgraph "External Network"
           Client[API Clients]
           BGP[BGP Router]
       end
       
       CP1 -.-> VIP
       CP2 -.-> VIP
       CP3 -.-> VIP
       VIP --> BGP
       BGP --> Client

**Implementation Details**:
- Kubernetes-native HA manages VIP assignment
- OVN BGP agent advertises active VIP location
- Sub-second failover with BFD
- No single point of failure

Dedicated Networker Node Deployment
------------------------------------

**Use Case**: Enterprise RHOSO deployment with dedicated networking infrastructure for BGP routing and tenant network isolation.

**Architecture Requirements**:

.. mermaid::

   ---
   config:
     theme: neutral
   ---
   graph TB
       subgraph "External Infrastructure"
           TOR1[ToR Switch 1<br/>AS 65000]
           TOR2[ToR Switch 2<br/>AS 65000]
           FW[Enterprise Firewall]
       end
       
       subgraph "OpenShift Cluster"
           subgraph "Control Plane Nodes"
               CP1[Master 1]
               CP2[Master 2] 
               CP3[Master 3]
           end
           
           subgraph "Dedicated Networker Nodes"
               NN1[Networker 1<br/>FRR + OVN BGP Agent<br/>CR-LRP Host]
               NN2[Networker 2<br/>FRR + OVN BGP Agent<br/>CR-LRP Host]
           end
           
           subgraph "Compute Nodes"
               CN1[Compute 1<br/>FRR + OVN BGP Agent]
               CN2[Compute 2<br/>FRR + OVN BGP Agent]
               CN3[Compute 3<br/>FRR + OVN BGP Agent]
           end
       end
       
       subgraph "Tenant Networks"
           T1[Tenant A: 10.1.0.0/24]
           T2[Tenant B: 10.2.0.0/24]
           T3[Tenant C: 10.3.0.0/24]
       end
       
       TOR1 -.->|eBGP| NN1
       TOR1 -.->|eBGP| CN1
       TOR2 -.->|eBGP| NN2
       TOR2 -.->|eBGP| CN2
       
       NN1 --> T1
       NN1 --> T2
       NN2 --> T2
       NN2 --> T3
       
       FW <--> TOR1
       FW <--> TOR2

**Benefits**:
- **Dedicated Traffic Path**: All north-south traffic controlled through networker nodes
- **High Availability**: Multiple networker nodes provide redundancy for tenant network access
- **Security Isolation**: Clear separation between compute and networking functions
- **Scalability**: Independent scaling of compute and network infrastructure

**Deployment Considerations**:
- **Hardware Requirements**: Networker nodes need enhanced networking capabilities
- **Network Connectivity**: Direct physical connections to external infrastructure
- **DVR**: Required before RHOSO 18.0.4, optional since (OSPRH-8429)
- **Monitoring**: Enhanced monitoring required for CR-LRP and gateway functions

Configuration and Deployment
=============================

Prerequisites
-------------

RHOSO dynamic routing requires:

- **RHOSO 18.0 or later** with ML2/OVN mechanism driver
- **RHOCP 4.16** (initial 18.0 release) or **4.18** (current feature releases)
- **BGP-capable network infrastructure** (ToR switches, routers)
- **Dedicated networker nodes** (mandatory for BGP deployments)
- **Proper network planning** for ASN assignment and IP addressing

.. note::
   Before RHOSO 18.0.4, dynamic routing also required Distributed Virtual Routing
   (DVR). Since 18.0.4, dynamic routing works without DVR (OSPRH-8429).

**Critical Architecture Requirements**:

- **No Control Plane OVN Gateways**: BGP is incompatible with control plane OVN gateway deployments
- **No Octavia Load Balancer**: Cannot be used simultaneously with BGP dynamic routing
- **No Distributed Control Plane**: RHOSO dynamic routing does not support distributed control planes across datacenters
- **Non-overlapping CIDRs**: When using tenant network advertising, all networks must use unique IP ranges
- **External BGP Peers**: Network infrastructure must support BGP peering and route filtering

.. note::
   **Cross-Datacenter Deployment Design Considerations**
   
   RHOSO BGP deployments across datacenters require additional planning and design considerations:
   
   - **Control Plane Design**: Consider the implications of control plane service communication patterns across WAN links
   - **Network Latency Planning**: Evaluate network latency requirements for optimal OpenStack service performance
   - **Database Architecture**: Plan for database replication, backup, and disaster recovery strategies
   - **Storage Design**: Consider storage architecture options that balance performance, availability, and data locality
   
   **Alternative Options**: Red Hat's **Distributed Compute Node (DCN)** architecture provides a proven approach for multi-site deployments with centralized control planes and distributed compute resources.

OpenShift Integration
---------------------

RHOSO BGP services integrate with OpenShift through:

**Pod Deployment**: BGP containers run as privileged pods with host networking
**ConfigMaps**: Configuration stored as Kubernetes ConfigMaps
**Monitoring**: Integration with OpenShift monitoring and alerting
**Networking**: Uses OpenShift SDN or OVN-Kubernetes for pod networking

Production Operations
=====================

Monitoring and Observability
-----------------------------

RHOSO BGP monitoring leverages OpenShift's native observability:

**Prometheus Metrics**: FRR and OVN BGP agent export metrics
**Grafana Dashboards**: Pre-built dashboards for BGP performance
**Alerting**: Automated alerts for BGP session failures
**Logging**: Centralized logging through OpenShift logging stack

.. code-block:: bash
   :caption: BGP Status Monitoring Commands

   # Check BGP session status
   oc exec -n openstack ds/frr-bgp -- vtysh -c 'show bgp summary'
   
   # View route advertisements
   oc exec -n openstack ds/frr-bgp -- vtysh -c 'show ip bgp neighbors advertised-routes'
   
   # Check OVN BGP agent status
   oc logs -n openstack -l app=ovn-bgp-agent --tail=50

Scaling Operations
------------------

Adding new compute capacity with BGP requires:

1. **OpenShift node addition**: Standard OpenShift node scaling procedures
2. **Automatic BGP configuration**: DaemonSets ensure BGP services on new nodes
3. **Network validation**: Verify BGP peering and route advertisement
4. **Workload validation**: Test VM connectivity through new nodes

Network Failure and Recovery
-----------------------------

RHOSO BGP deployments implement automated failure detection and recovery mechanisms:

.. mermaid::

   ---
   config:
     theme: neutral
   ---
   flowchart TD
       START([Normal Operation<br/>BGP Sessions Active]) --> MONITOR{Monitoring<br/>Systems}
       
       MONITOR -->|BGP Session Failure| BGP_FAIL[BGP Session Down]
       MONITOR -->|Node Failure| NODE_FAIL[Networker Node Down]
       MONITOR -->|BFD Timeout| BFD_FAIL[BFD Session Timeout]
       
       BGP_FAIL --> BGP_DETECT{Failure Detection<br/>Method}
       BGP_DETECT -->|BFD Enabled| BFD_FAST[Sub-second Detection<br/>100~300ms]
       BGP_DETECT -->|BGP Keepalive Only| BGP_SLOW[Standard Detection<br/>30~90 seconds]
       
       BFD_FAST --> WITHDRAW_ROUTES[Withdraw BGP Routes<br/>from Failed Peer]
       BGP_SLOW --> WITHDRAW_ROUTES
       BFD_FAIL --> WITHDRAW_ROUTES
       
       NODE_FAIL --> CR_LRP_CHECK{CR-LRP Migration<br/>Available?}
       CR_LRP_CHECK -->|Yes| CR_LRP_MIGRATE[Migrate CR-LRP to<br/>Healthy Networker Node]
       CR_LRP_CHECK -->|No| TENANT_OUTAGE[Tenant Network<br/>Connectivity Lost]
       
       WITHDRAW_ROUTES --> REROUTE[Traffic Rerouted<br/>via Remaining Peers]
       CR_LRP_MIGRATE --> REROUTE
       
       REROUTE --> RECOVERY_CHECK{Service<br/>Recovery?}
       RECOVERY_CHECK -->|BGP Peer Recovery| PEER_RECOVERY[Re-establish<br/>BGP Session]
       RECOVERY_CHECK -->|Node Recovery| NODE_RECOVERY[Node Rejoins<br/>Cluster]
       
       PEER_RECOVERY --> READVERTISE[Re-advertise<br/>BGP Routes]
       NODE_RECOVERY --> POD_RESTART[Restart BGP<br/>Services]
       POD_RESTART --> READVERTISE
       
       READVERTISE --> CONVERGE[Network<br/>Convergence]
       CONVERGE --> START
       
       TENANT_OUTAGE --> MANUAL_INTERVENTION[Manual Intervention<br/>Required]
       MANUAL_INTERVENTION -->|Add Networker Node| NODE_RECOVERY

**Failure Scenarios and Recovery Times**:

.. list-table:: RHOSO BGP Failure Recovery Matrix
   :widths: 30 25 25 20
   :header-rows: 1

   * - Failure Type
     - Detection Time
     - Recovery Time
     - Impact Level
   * - BGP Session Failure (BFD enabled)
     - 100~300ms
     - 1~3 seconds
     - Low (alternate paths)
   * - BGP Session Failure (no BFD)
     - 30~90 seconds
     - 30~120 seconds
     - Medium (delayed reroute)
   * - Single Networker Node
     - 5~15 seconds
     - 10~30 seconds
     - Medium (CR-LRP migration)
   * - Multiple Networker Nodes
     - 5~15 seconds
     - Manual intervention
     - High (tenant isolation)
   * - Compute Node
     - 30~60 seconds
     - 60~180 seconds
     - Low (workload migration)

**Automated Recovery Mechanisms**:

- **BGP Route Withdrawal**: Automatic route withdrawal upon session failure
- **BFD Fast Detection**: Sub-second failure detection with proper BFD configuration
- **CR-LRP Migration**: Automatic migration of Chassis Redirect Logical Router Ports
- **Traffic Rerouting**: ECMP and alternate path utilization
- **Session Re-establishment**: Automatic BGP session recovery

Troubleshooting
===============

Common Issues and Solutions
---------------------------

**BGP Sessions Not Establishing**

Symptoms: BGP peers show "Idle" or "Connect" state

.. code-block:: bash
   :caption: Diagnosis Commands

   # Check BGP peer status
   oc exec -n openstack ds/frr-bgp -- vtysh -c 'show bgp neighbors'
   
   # Verify network connectivity
   oc exec -n openstack ds/frr-bgp -- ping <peer-ip>
   
   # Check firewall rules
   oc exec -n openstack ds/frr-bgp -- ss -tulpn | grep 179

**Solution**: Verify network connectivity, ASN configuration, and firewall rules allowing TCP port 179.

**Routes Not Being Advertised**

Symptoms: External networks cannot reach RHOSO workloads

.. code-block:: bash
   :caption: Diagnosis and Resolution

   # Check if IPs are on bgp-nic interface
   oc exec -n openstack ds/ovn-bgp-agent -- ip addr show bgp-nic
   
   # Verify FRR is redistributing connected routes
   oc exec -n openstack ds/frr-bgp -- vtysh -c 'show running-config'
   
   # Check OVN BGP agent logs
   oc logs -n openstack -l app=ovn-bgp-agent

**Solution**: Ensure OVN BGP agent is running and FRR has "redistribute connected" configured.

**Tenant Networks Not Reachable**

Symptoms: External clients cannot reach VMs on tenant networks despite `expose_tenant_network = True`

.. code-block:: bash
   :caption: Tenant Network Troubleshooting

   # Check if tenant network exposure is enabled
   oc exec -n openstack ds/ovn-bgp-agent -- grep expose_tenant_network /etc/ovn_bgp_agent/ovn_bgp_agent.conf
   
   # Verify CR-LRP (Chassis Redirect Logical Router Ports) are active on networker nodes
   oc exec -n openstack ds/ovn-bgp-agent -- ovn-sbctl show | grep cr-lrp
   
   # Check neutron router gateway port advertisement
   oc exec -n openstack ds/frr-bgp -- vtysh -c 'show ip bgp | grep 10.0.0'

**Solution**: Verify networker nodes are hosting CR-LRP and neutron router gateways are properly advertised.

**Networker Node Failures**

Symptoms: Complete loss of external connectivity to tenant networks

.. code-block:: bash
   :caption: Networker Node Failure Diagnosis

   # Check networker node health
   oc get nodes -l node-role.kubernetes.io/rhoso-networker
   
   # Verify networker pods are running
   oc get pods -n openstack -l app=rhoso-networker
   
   # Check CR-LRP failover status
   oc exec -n openstack ds/ovn-bgp-agent -- ovn-sbctl find Chassis_Redirect_Port
   
   # Verify BGP session status on remaining networker nodes
   oc exec -n openstack ds/frr-bgp -- vtysh -c 'show bgp summary'

**Solution**: Ensure multiple networker nodes are deployed for high availability and CR-LRP can migrate between nodes.

**Slow Convergence**

Symptoms: Long failover times during node or network failures

.. code-block:: text
   :caption: BFD Configuration for Fast Convergence

   router bgp 64999
     neighbor 172.30.1.254 bfd
     neighbor 172.30.1.254 bfd profile fast-detect
   
   bfd
     profile fast-detect
       detect-multiplier 3
       receive-interval 100
       transmit-interval 100

Known Issues
-------------

Both issues below were originally filed against RHOSP 17.1 but are still listed in the
RHOSO 18.0 dynamic routing documentation:

- **Floating IP port forwarding**: Port forwarding with floating IPs fails when BGP dynamic routing is enabled (BZ 2160481)
- **Multicast routing**: Multicast routing is not supported with BGP dynamic routing (BZ 2163477, CLOSED WONTFIX)
- **DNS service (designate)**: Unsupported in dynamic routing environments; the
  designate-worker pods cannot configure the BIND backend

Performance Tuning
-------------------

**ECMP Configuration**

.. code-block:: text
   :caption: Optimized ECMP Settings

   router bgp 64999
     maximum-paths 8
     maximum-paths ibgp 8
     bestpath as-path multipath-relax

**BGP Timers Optimization**

.. code-block:: text
   :caption: Production BGP Timers

   router bgp 64999
     neighbor 172.30.1.254 timers 10 30
     neighbor 172.30.1.254 capability extended-nexthop
