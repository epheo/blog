
Case Studies and Use Cases
==========================


Real-World Scenarios
--------------------

Let's explore some real-world scenarios using BGP plays Red Hat OpenStack deployments:

- **Scenario 1: Control Plane VIP**

  In this scenario, BGP is used to advertise the control plane VIP to external BGP 
  peers. This allows the control plane to be accessed from outside, enabling 
  remote management of the OpenStack environment.

  Controllers could be in separated sites, edge locations or Availability Zones (AZs).

  In the following example the controllers are located in separated racks with 
  different subnets which provides resilience against power disruptions.
  
  Rather than relying on traditional L2-based methods like keepalived or VRRP for 
  failover detection, we leverage Pacemaker with L3 IP to determine the liveliness of 
  controllers.

  Controller-1, operating as the active node, utilizes BGP to announce the external 
  VIP 192.1.1.1 to Leaf/ToR1

  The OpenStack client connects to the Controller-1 VIP and the OpenStack API services 
  are load balanced by the HAproxy service of the Controller-1.


.. figure:: bgp.controlplane.png
   :width: 100%
   :align: center



- **Scenario 2: Multi-Cloud Connectivity**

  BGP can be utilized to interconnect multiple OpenStack clouds, facilitating resources 
  inter-connectivity within a same datacenter or accross SD-WAN using Calico or AWS 
  interconnect.
  
.. figure:: bgp.multicloud.png
   :width: 100%
   :align: center


- **Scenario 3: Bonding and Loadbalancing with ECMP** 

  BGP can be employed to create redundancy and load balancing for critical services 
  hosted within Red Hat OpenStack. 
  
  Equal-Cost Multi-Path (ECMP) load balancing allows for the simultaneous use of 
  multiple network paths for load distribution, optimizing resource utilization, and 
  enhancing network resilience.

  BGP can help creating redundant network paths and facilite automatic failover when 
  network or hardware failures occur.

- **Scenario 4: Scaling OpenStack Infrastructure**

  As OpenStack environments expand, managing network routing becomes increasingly complex. 
  BGP simplifies this process by dynamically adjusting routing tables as new resources 
  are added. 
  