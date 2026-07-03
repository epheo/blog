Notes & How-To Guides
=====================

Shorter notes and how-tos: the commands I keep looking up and the setups
I don't want to figure out twice.

Categories
----------

.. dropdown:: Container Technologies
   :icon: container
   :animate: fade-in
   :open:

   * :doc:`OpenShift Virtualization Sidecar </notes/kubevirt-sidecar>` - Rewrite the libvirt domain XML of a running VM with a hook sidecar
   * :doc:`Merging kubeconfig Files </notes/merge-kubeconfig>` - One kubeconfig for all your clusters
   * :doc:`OpenShift Console Banner </notes/openshift-banner>` - A colored banner so you stop applying things to prod by mistake
   * :doc:`Podman </notes/podman>` - The Podman commands I keep looking up: squash, Quadlet, pods, pasta

.. dropdown:: Linux Administration
   :icon: terminal
   :animate: fade-in
   :open:

   * :doc:`Linux File Permissions and ACLs </notes/linux/droits-multiples-et-acl/index>` - setfacl, getfacl, masks, default ACLs, and Samba integration

.. dropdown:: AI & GPU
   :icon: cpu
   :animate: fade-in
   :open:

   * :doc:`Running vLLM on Strix Halo </notes/strix-halo/index>` - Building vLLM against ROCm nightlies on gfx1151, OpenStack-early-days vibes

.. dropdown:: Concepts & Thoughts
   :icon: light-bulb
   :animate: fade-in
   :open:

   * :doc:`Defms </notes/defms/index>` - A 2018 essay on a distributed, encrypted and free mail system

Quick Reference
---------------

.. tab-set::

   .. tab-item:: OpenShift

      .. code-block:: bash

         # Merge kubeconfig files
         KUBECONFIG=~/.kube/config:~/new-cluster-config kubectl config view --flatten > ~/.kube/merged-config
         export KUBECONFIG=~/.kube/merged-config

         # Set console banner (ConsoleNotification, see the banner note)
         oc apply -f - <<'EOF'
         apiVersion: console.openshift.io/v1
         kind: ConsoleNotification
         metadata:
           name: banner
         spec:
           text: This is a test environment
           location: BannerTop
           backgroundColor: '#0f4414'
           color: '#ffffff'
         EOF

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

         # Build from Containerfile
         podman build -t myapp .

         # Quadlet: drop a .container file for systemd integration
         # ~/.config/containers/systemd/myapp.container
         # then: systemctl --user daemon-reload && systemctl --user start myapp

.. toctree::
   :maxdepth: 1
   :hidden:

   kubevirt-sidecar
   merge-kubeconfig
   openshift-banner
   podman
   defms/index
   linux/droits-multiples-et-acl/index
   strix-halo/index
