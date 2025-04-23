Understanding BGP Basics
========================


BGP Fundamentals
----------------

BGP (Border Gateway Protocol) is a standardized exterior gateway protocol (EGP) defined in RFC 4271 that plays a 
central role in how the global routing of Internet traffic is performed. It is considered the routing protocol of the Internet and enables routing across administrative domains.

Here are some fundamental concepts of BGP:

- **Path Vector Protocol**: BGP is a path vector protocol, meaning it keeps track of 
  the path (sequence of ASes) that routes take through the Internet. 
  
  This information helps BGP in making routing decisions.

- **Autonomous Systems (ASes)**: Autonomous systems are individual networks or groups 
  of networks managed by a single entity and that operates under a common routing policy.
  
  Each AS is assigned a unique Autonomous System Number (ASN), which is used to identify it.

- **BGP Peers**: BGP routers establish peering sessions with other BGP routers (peers). 
  
  Peering is typically done using TCP connections. 
  
  BGP routers exchange routing updates and route information with their peers.


BGP Use Cases in OpenStack
---------------------------

In the context of OpenStack, BGP can be used in multiple ways to facilitate different use cases:

1. **Control Plane VIP**: BGP is used to advertise the Control Plane VIP (Virtual IP) 
   to external routers. 
   
   This enables the routing of traffic to the OpenStack Control Plane by external routers.

2. **External Connectivity**: BGP is used to connect OpenStack workload to external 
   networks, such as the Internet or private data centers. 

   This enables the routing of traffic between OpenStack instances and the outside 
   world by advertising routes to floating IPs and VLAN provider IPs to external routers.

3. **Multi cloud Connectivity**: BGP is used to connect multiple OpenStack clouds together. 

   This enables the routing of traffic between instances in different OpenStack clouds 
   by advertising routes to external routers.

4. **High Availability**: BGP is instrumental in achieving high availability and 
   redundancy by allowing traffic to be rerouted in the event of network failures. 
   
   This ensures minimal downtime for critical applications.


Benefits of Dynamic Routing with BGP
-------------------------------------

Dynamic routing with BGP offers several benefits in the context of OpenStack:

- **Scalability**: BGP scales seamlessly, making it suitable for growing OpenStack 
  environments. New networks and floating IPs (FIPs) can be routed without manual configuration,
  allowing for easier expansion of your cloud infrastructure.

- **Load Balancing**: BGP supports equal-cost multi-path routing (ECMP), which can distribute 
  traffic across multiple paths, optimizing network utilization and ensuring efficient load balancing.

- **Redundancy**: BGP provides high availability by automatically rerouting traffic in case of 
  network failures, reducing the risk of service interruptions. This is especially important
  for controllers deployed across availability zones with separate L2 segments or physical sites.

- **Interoperability**: BGP is a widely accepted standard, ensuring compatibility with 
  various networking devices and cloud platforms. This simplifies integration with existing
  network infrastructure.
  
- **Simplified L3 Architecture**: Deploying clusters in a pure Layer 3 (L3) data center with BGP
  overcomes the scaling issues of traditional Layer 2 (L2) infrastructures such as large failure domains,
  high volume broadcast traffic, or long convergence times during failure recoveries.
