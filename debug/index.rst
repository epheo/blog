Troubleshooting & Debugging
============================

Notes written mid-incident: what broke, how I traced it, and what actually fixed it.

* :doc:`OpenStack OVN Networking </debug/openstack-ovn>` - Tracing security group
  rules from Neutron down to OpenFlow, packet simulation with ``ovn-trace``, and
  DHCP delivery: field notes from the RHOSP 16 era
* :doc:`PostgreSQL on OpenShift </debug/postgresql-openshift>` - Recovering from a
  "tuple concurrently updated" crash loop after an unclean shutdown

.. toctree::
   :maxdepth: 1
   :hidden:

   postgresql-openshift
   openstack-ovn
