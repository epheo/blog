.. meta::
   :description:
      BGP Implementation in Red Hat OpenStack Platform using FRR
   :keywords:
      OpenStack, Red Hat, BGP, FRR, ECMP, ML2/OVN


.. _intro_section:

*************************************************
BGP Implementation in Red Hat OpenStack using FRR
*************************************************

.. article-info::
    :date: Sept 24, 2023
    :read-time: 5 min read


Introduction
============

Border Gateway Protocol (BGP) enables efficient routing in large-scale environments 
and has become essential for connecting network segments without Layer 2 spanning 
technologies or static routing.

Red Hat OpenStack Platform integrates Free Range Routing (FRR) with the OVN BGP agent 
to provide dynamic routing capabilities with ML2/OVN in both control and data planes. 
This enables pure Layer 3 data center architectures that overcome traditional Layer 2 
limitations such as large failure domains and slow convergence during network failures.

This document provides a technical overview of BGP in Red Hat OpenStack Platform, 
including architecture details, configuration examples, and implementation scenarios.


.. contents::
   :local:
   :depth: 2

.. include:: bgp-basics.rst
.. include:: architecture.rst
.. include:: why-frr.rst   
.. include:: use-cases.rst
.. include:: managing-bgp-routes.rst
.. include:: troubleshooting.rst