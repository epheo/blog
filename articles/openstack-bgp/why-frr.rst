
FRR: The Free Range Routing Suite
==================================

The Free Range Routing (FRR) suite is the main component behind the BGP implementation 
within Red Hat OpenStack. 

Introduction to FRR
-------------------

**Free Range Routing (FRR)** is an open-source routing suite that provides a 
comprehensive set of routing protocols and features for Linux-based systems. 

FRR originated as a fork of Quagga, aiming to overcome limitations and enhance the 
capabilities of traditional routing software. 

Key points to grasp about FRR include:

- **Open Source**: FRR is released under an open-source license, with a strong 
  community-driven development approach that encourages fast innovation.

- **Extensive Protocol Support**: FRR supports various routing protocols, including 
  BGP, OSPF, IS-IS, RIP, and more. This versatility makes it suitable for diverse 
  networking environments.

- **Robust and Scalable**: FRR is designed for robustness and scalability, this 
  makes it suitable for both small-scale deployments and large, complex networks.

- **Dynamic Routing**: FRR facilitates dynamic routing, enabling routers to exchange 
  routing information and make real-time decisions about data packet forwarding.


FRR Features and Capabilities
-----------------------------

FRR offers a rich set of features and capabilities, making it a defacto choice for 
the BGP implementation in Red Hat OpenStack:

- **Advanced BGP Support**: FRR provides extensive support for BGP, including eBGP 
  and iBGP, route reflectors, and route aggregation. 
  This allows fine-grained control over BGP routing policies.

- **Dynamic Routing Updates**: FRR ensures real-time updates and synchronization of 
  routing tables, responding to network changes efficiently.

- **Redundancy and High Availability**: FRR supports features like VRRP (Virtual 
  Router Redundancy Protocol) and HSRP (Hot Standby Router Protocol), enhancing 
  network reliability and availability.

- **Integration with OpenStack**: Red Hat Engineering has integrated FRR within its 
  OpenStack offering, making it the solution for implementing BGP within your 
  OpenStack environment.


Why FRR in Red Hat OpenStack?
-----------------------------

The decision to incorporate FRR into Red Hat OpenStack holds several advantages:

- **Open Source Synergy**: FRR aligns with the open-source philosophy that underpins 
  both FRR and Red Hat OpenStack. This synergy fosters innovation and ensures 
  compatibility with evolving networking standards.

- **Robust BGP Functionality**: FRR's robust BGP support empowers network 
  administrators to implement complex BGP routing policies, ensuring efficient data 
  flow and dynamic adaptation to network changes.

- **Strong Community**: FRR benefits from an active and engaged community of users 
  and developers, providing access to expertise, updates, and contributions from a 
  diverse network of professionals.

