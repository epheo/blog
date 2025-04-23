.. meta::
   :description:
      Discover the BGP Implementation in Red Hat OpenStack using FRR
   :keywords:
      OpenStack, RedHat, BGP, FRR, ECMP


.. _intro_section:

*************************************************
BGP Implementation in Red Hat OpenStack using FRR
*************************************************

.. article-info::
    :date: Sept 24, 2023
    :read-time: 5 min read


Introduction
============

The Border Gateway Protocol (BGP) is widely used over the internet for managing routes 
and enabling efficient data transfer within large-scale environments. As organizations 
move toward more distributed infrastructures, BGP has become essential for connecting 
multiple network segments without relying on Layer 2 spanning technologies or static routing.

Red Hat OpenStack Platform has incorporated the Free Range Routing (FRR) suite with the 
OVN BGP agent to provide dynamic routing capabilities. This integration enables pure Layer 3 
data center architectures that overcome traditional Layer 2 scaling limitations such as 
large failure domains and convergence delays during network failures.

This document provides a technical overview of the BGP implementation in Red Hat OpenStack 
Platform using FRR, including architecture details, configuration examples, and real-world 
use cases.


.. contents::
   :local:
   :depth: 2

.. include:: bgp-basics.rst
.. include:: architecture.rst
.. include:: why-frr.rst   
.. include:: use-cases.rst
.. include:: managing-bgp-routes.rst