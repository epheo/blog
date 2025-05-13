Troubleshooting BGP in Red Hat OpenStack Platform
======================================================

Diagnosing problems in a Red Hat OpenStack Platform environment that uses BGP begins with examining logs and querying FRR components with VTY shell.

Log Locations
-------------

The key log files for troubleshooting BGP issues are:

* **OVN BGP Agent logs**: Located on Compute and Networker nodes
  
  .. code-block:: text
  
      /var/log/containers/stdouts/ovn_bgp_agent.log

* **FRR component logs**: Located on all nodes where FRR is running
  
  .. code-block:: text
  
      /var/log/containers/frr/frr.log

Using VTY Shell for Troubleshooting
-----------------------------------

VTY shell allows interaction with FRR daemons to diagnose BGP routing issues.

**Accessing VTY Shell**

1. Log in to the node where you need to troubleshoot BGP
2. Enter the FRR container:
   
   .. code-block:: bash
   
       $ sudo podman exec -it frr bash

3. You can use VTY shell in two different modes:

   * **Interactive mode**:
     
     .. code-block:: bash
     
         $ sudo vtysh
         > show bgp summary

   * **Direct mode**:
     
     .. code-block:: bash
     
         $ sudo vtysh -c 'show bgp summary'

**Useful Troubleshooting Commands**

The following commands help diagnose common BGP issues:

* **Display BGP routing tables**:
  
  .. code-block:: bash
  
      # For IPv4
      > show ip bgp <IPv4_address> | all
      
      # For IPv6 (omit the 'ip' argument)
      > show bgp <IPv6_address> | all

* **Show routes advertised to a peer**:
  
  .. code-block:: bash
  
      > show ip bgp neighbors <router-ID> advertised-routes

* **Show routes received from a peer**:
  
  .. code-block:: bash
  
      > show ip bgp neighbors <router-ID> received-routes

* **Check BGP peer status**:
  
  .. code-block:: bash
  
      > show bgp summary

* **Verify BGP configuration**:
  
  .. code-block:: bash
  
      > show running-config

Common BGP Issues
-----------------

Here are some common issues you might encounter and how to address them:

1. **BGP Peers Not Establishing Connection**
   
   * Check IP connectivity between peers
   * Verify ASN configuration matches on both sides
   * Check for firewall rules blocking BGP port (TCP 179)
   * Examine logs for capability negotiation issues

2. **Routes Not Being Advertised**
   
   * Verify the OVN BGP agent is running
   * Check if IP addresses are added to the bgp-nic interface
   * Inspect FRR configuration for proper route redistribution
   * Check for route filtering that might prevent advertisement

3. **Traffic Not Reaching VMs**
   
   * Verify OVS flow rules are correctly installed
   * Check IP rules and routing table entries
   * Ensure ARP/NDP proxy is enabled on the provider bridge
   * Confirm VRF configuration is correct

4. **Slow Convergence After Failures**
   
   * Check if BFD is enabled and configured correctly
   * Verify timers are set appropriately
   * Inspect BGP graceful restart configuration
   * Check for any route dampening that might delay reconvergence 