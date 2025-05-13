Troubleshooting & Debugging
============================

This section contains technical articles focused on debugging various systems and applications.

Featured Debugging Guides
-------------------------

.. grid:: 2

    .. grid-item-card::  :octicon:`database` PostgreSQL on OpenShift
        :link: postegresql_openshift
        :link-type: doc
        :class-card: sd-rounded-3

        Troubleshooting for PostgreSQL deployments running on OpenShift, covering common issues and their solutions.

    .. grid-item-card::  :octicon:`server` OpenStack OVN Networking
        :link: openstack-ovn
        :link-type: doc
        :class-card: sd-rounded-3

        Deep dive into OVN networking architecture in OpenStack, with detailed debugging techniques for common problems.

Debugging by Platform
---------------------

.. tab-set::

    .. tab-item:: OpenShift
        :sync: openshift-debug

        .. dropdown:: PostgreSQL on OpenShift
           :animate: fade-in
           :class-title: sd-fs-5
           :class-body: sd-fs-6

           Troubleshooting for PostgreSQL instances running on OpenShift:

           * Database connection issues
           * Performance bottlenecks
           * Storage-related problems
           * Backup and recovery scenarios

           :doc:`Read the full guide </debug/postegresql_openshift>`

    .. tab-item:: OpenStack
        :sync: openstack-debug

        .. dropdown:: OVN Networking
           :animate: fade-in
           :class-title: sd-fs-5
           :class-body: sd-fs-6

           Debugging OVN networking issues in OpenStack:

           * Understanding the OVN architecture
           * Network traffic flow analysis
           * Common failure scenarios and their solutions
           * Command-line debugging tools

           :doc:`Read the full guide </debug/openstack-ovn>`

Debugging Cheat Sheets
----------------------

.. admonition:: OpenShift PostgreSQL Debugging
   :class: tip

   .. code-block:: bash

      # Get PostgreSQL pod status
      oc get pods -l app=postgresql

      # Check logs
      oc logs <pod-name>

      # Connect to PostgreSQL instance
      oc rsh <pod-name>
      psql -U postgres

      # Check PostgreSQL configuration
      oc exec <pod-name> -- cat /opt/bitnami/postgresql/conf/postgresql.conf

.. admonition:: OpenStack OVN Debugging
   :class: tip

   .. code-block:: bash

      # List OVN northbound database content
      ovn-nbctl show

      # List OVN southbound database content
      ovn-sbctl show

      # Check logical flows
      ovn-sbctl lflow-list

      # Trace a packet through OVN
      ovn-trace <switch> "inport=<port_id> ... <packet details>"

Complete Debugging Resources
----------------------------

.. toctree::
   :maxdepth: 1

   postegresql_openshift
   openstack-ovn
