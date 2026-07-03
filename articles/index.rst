Articles
========

In-depth guides from my lab: OpenShift, Kubernetes, and whatever hardware or
software problem kept me busy long enough to write it down.

Categories
----------

.. dropdown:: OpenShift
   :icon: container
   :animate: fade-in
   :open:

   * :doc:`OpenShift Layer 2 UDN </articles/openshift-layer2-udn/index>` - Isolated tenant networks for VMs: one virtual switch across the cluster, live migration included
   * :doc:`OpenShift LocalNet </articles/openshift-localnet/index>` - VMs with IPs from the baremetal network, reusing the existing ``br-ex`` bridge
   * :doc:`OpenShift Workstation </articles/openshift-workstation/index>` - GPU passthrough on single-node OpenShift; yes, it runs Flight Simulator
   * :doc:`OpenShift Ollama </articles/openshift-ollama/index>` - Mistral 7B on OpenShift, with a Telegram bot in front
   * :doc:`OpenShift Block Device Backup </articles/openshift-borg/index>` - LVM volumes backed up to FreeNAS with BorgBackup CronJobs, lab-grade by design

.. dropdown:: Kubernetes
   :icon: package
   :animate: fade-in
   :open:

   * :doc:`Ultra Fast Static Server in Rust </articles/kiss-rust-server/index>` - The 454 KiB server behind this page, written to save 0.005€
   * :doc:`SOPS + Age + Git Secret Management </articles/k8s-sops-secrets/index>` - Plain-text secrets in the working tree, encrypted in Git, no Vault required
   * :doc:`NGINX Ingress Router Sharding </articles/k8s-nginx-ingress-sharding/index>` - Public and private services on separate interfaces with two NGINX controllers

.. toctree::
   :maxdepth: 1
   :hidden:

   openshift-layer2-udn/index
   openshift-localnet/index
   openshift-workstation/index
   openshift-ollama/index
   openshift-borg/index
   kiss-rust-server/index
   k8s-sops-secrets/index
   k8s-nginx-ingress-sharding/index
