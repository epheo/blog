Understanding BGP Basics
========================

BGP Fundamentals
----------------

BGP (Border Gateway Protocol) is a standardized exterior gateway protocol designed for routing across administrative domains. It serves as the primary routing protocol of the Internet.

Key BGP concepts:

- **Path Vector Protocol**: BGP tracks the sequence of Autonomous Systems (ASes) that routes traverse, using this information for routing decisions.

- **Autonomous Systems**: Networks managed by a single entity under a common routing policy. Each AS has a unique Autonomous System Number (ASN).

- **BGP Peers**: BGP routers establish TCP-based connections with other BGP routers to exchange routing information.

BGP Use Cases in OpenStack
--------------------------

Red Hat OpenStack Platform specifically supports ML2/OVN dynamic routing with BGP in both control and data planes. In this environment, BGP enables:

1. **Control Plane High Availability**: Advertises control plane Virtual IPs to external routers, directing traffic to OpenStack services.

2. **External Connectivity**: Connects OpenStack workloads to external networks by advertising routes to floating IPs and provider network IPs.

3. **Multi-cloud Connectivity**: Links multiple OpenStack clouds together through route advertisement.

4. **High Availability**: Provides redundancy by rerouting traffic during network failures.

5. **Subnet Failover**: Enables failover of entire subnets for public provider IPs or floating IPs from one site to another.

Benefits of Dynamic Routing with BGP
-------------------------------------

BGP offers significant advantages for OpenStack environments:

- **Scalability**: New networks and floating IPs can be routed without manual configuration.

- **Load Balancing**: Supports equal-cost multi-path routing (ECMP) to distribute traffic efficiently.

- **Redundancy**: Automatically reroutes traffic during network failures, critical for controllers deployed across multiple availability zones.

- **Interoperability**: Works with diverse networking equipment and cloud platforms.

- **Simplified L3 Architecture**: Enables pure Layer 3 data centers, avoiding Layer 2 issues like large failure domains, broadcast traffic, and slow convergence.

- **Distributed Network Architecture**: Distributes L2 provider VLANs and floating IP subnets across L3 boundaries with no requirement to span VLANs across racks (for non-overlapping CIDRs).

- **Improved Data Plane Management**: Provides better control and management of data plane traffic.

- **Next-Generation Fabric Support**: Enables integration with next-generation data center and hyperscale fabric technologies.
