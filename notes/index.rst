Notes & How-To Guides
=====================

This section contains technical notes, tips, and how-to guides on various topics including Linux and container technologies.

Featured Notes
--------------

.. card:: OpenShift Virtualization Sidecar
   :link: kubevirt-sidecar
   :link-type: doc
   :class-card: sd-rounded-3

   **Customize virtual machines by modifying libvirt domain XML using sidecar containers**
   
   Learn how to use the sidecar pattern to customize and extend virtual machines running on OpenShift Virtualization.
   This guide covers the complete process from setup to implementation.

.. card-carousel:: 2

   .. card:: Merging kubeconfig Files
      :link: merge-kubeconfig
      :link-type: doc
      :class-card: sd-rounded-3

      Learn how to merge multiple kubeconfig files for Kubernetes and OpenShift for easy cluster management.

   .. card:: OpenShift Console Banner
      :link: openshift-banner
      :link-type: doc
      :class-card: sd-rounded-3

      Set a console banner in OpenShift to display important information to users.

   .. card:: Working with Podman
      :link: podman
      :link-type: doc
      :class-card: sd-rounded-3

      Essential notes and commands for working with Podman container technology.

   .. card:: Linux File Permissions and ACLs
      :link: linux/droits-multiples-et-acl/index
      :link-type: doc
      :class-card: sd-rounded-3

      Detailed guide on managing complex Linux file permissions and Access Control Lists.

Categories
----------

.. dropdown:: Container Technologies
   :icon: container
   :animate: fade-in

   * :doc:`OpenShift Virtualization Sidecar </notes/kubevirt-sidecar>` - How to customize virtual machines with sidecar containers
   * :doc:`Merging kubeconfig Files </notes/merge-kubeconfig>` - How to merge multiple kubeconfig files for Kubernetes and OpenShift
   * :doc:`OpenShift Console Banner </notes/openshift-banner>` - Set a console banner in OpenShift
   * :doc:`Podman </notes/podman>` - Notes on Podman container runtime and commands

.. dropdown:: Linux Administration
   :icon: terminal
   :animate: fade-in

   * :doc:`Linux File Permissions and ACLs </notes/linux/droits-multiples-et-acl/index>` - Working with complex permissions and Access Control Lists

.. dropdown:: Concepts & Thoughts
   :icon: light-bulb
   :animate: fade-in

   * :doc:`Defms </notes/defms/index>` - A Distributed, Encrypted and Free Mail System

Quick Reference
---------------

.. tab-set::

   .. tab-item:: OpenShift

      .. code-block:: bash

         # Merge kubeconfig files
         KUBECONFIG=~/.kube/config:~/new-cluster-config kubectl config view --flatten > ~/.kube/merged-config
         export KUBECONFIG=~/.kube/merged-config

         # Set console banner
         oc patch consoles.operator.openshift.io cluster --patch '{"spec":{"customization":{"customLogoFile":"","customProductName":"","customBannerText":"This is a test environment"}}}' --type=merge

   .. tab-item:: KubeVirt

      .. code-block:: yaml

         apiVersion: kubevirt.io/v1
         kind: VirtualMachine
         spec:
           template:
             spec:
               domain:
                 devices:
                   disks:
                   - name: containerdisk
                     disk:
                       bus: virtio
                   - name: cloudinitdisk
                     disk:
                       bus: virtio

   .. tab-item:: Podman

      .. code-block:: bash

         # Run a container
         podman run -d --name web -p 8080:80 nginx

         # List containers
         podman ps

         # Build from Dockerfile
         podman build -t myapp .

         # Generate systemd unit file
         podman generate systemd --name mycontainer > ~/.config/systemd/user/mycontainer.service

Complete Notes Index
----------------------

.. toctree::
   :maxdepth: 1

   kubevirt-sidecar
   merge-kubeconfig
   openshift-banner
   podman
   defms/index
   linux/droits-multiples-et-acl/index
