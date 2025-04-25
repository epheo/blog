.. meta::
   :description:
      How to customize OpenShift Virtualization virtual machines by modifying libvirt domain XML using sidecar containers
   :keywords:
      OpenShift, KubeVirt, Sidecar, CNV, Container Native Virtualization, VM, Kubernetes, Libvirt, xml, domain

.. _kubevirt_sidecar_section:

******************************************************
OpenShift Virtualization Sidecar Implementation Guide
******************************************************

.. article-info::
    :date: April 25, 2025
    :read-time: 8 min read


Overview
========

The Sidecar feature in Kubevirt enables the attachment of additional containers to virtual machine pods. These sidecar containers run alongside the VM container, allowing for enhanced functionality such as monitoring, logging, debugging, and custom modifications to the VM environment without modifying the core VM itself.

This document provides instructions for enabling and implementing the Sidecar feature in an OpenShift Container Native Virtualization (CNV) environment.


Enabling the Sidecar Feature Gate
=================================

The Sidecar feature is controlled by a feature gate which must be explicitly enabled:

.. code-block:: bash

    kubectl annotate --overwrite -n openshift-cnv hco kubevirt-hyperconverged \
      kubevirt.kubevirt.io/jsonpatch='[{"op": "add", "path": "/spec/configuration/developerConfiguration/featureGates/-", "value": "Sidecar"}]'

Verify Feature Gate is Enabled
-------------------------------

To confirm the feature gate has been successfully added:

.. code-block:: bash

    kubectl get kubevirt kubevirt-kubevirt-hyperconverged -n openshift-cnv \
      -o jsonpath='{.spec.configuration.developerConfiguration.featureGates}'

The output should include ``Sidecar`` in the list of enabled feature gates.

Implementing a Sidecar Container
================================

KubeVirt Hook Types
--------------------

KubeVirt sidecars support different hook types for various modification purposes:

* **onDefineDomain**: Modifies the libvirt XML domain definition before VM creation
* **preCloudInitIso**: Modifies cloud-init data before the ISO is generated

Sidecar Script Arguments
-------------------------

When writing sidecar scripts, it's important to understand how arguments are passed to your script:

For **onDefineDomain** hook:
  
1. **Argument 1**: The hook name (onDefineDomain)
2. **Argument 2**: The ``--version`` parameter (e.g., v1alpha2)
3. **Argument 3**: The ``--vmi`` parameter with VMI information as JSON string
4. **Argument 4**: The ``--domain`` parameter with the current domain XML

For **preCloudInitIso** hook:

1. **Argument 1**: The hook name (preCloudInitIso)
2. **Argument 2**: The ``--version`` parameter (e.g., v1alpha2)
3. **Argument 3**: The ``--vmi`` parameter with VMI information as JSON string
4. **Argument 4**: The ``--cloud-init`` parameter with CloudInitData as JSON

.. note::

   * Your script should read the input XML/JSON from the appropriate argument (usually the 4th argument).
   * It must output the modified content to standard output (stdout).
   * The script must preserve any XML/JSON structure while making targeted modifications.
   * Any errors should be directed to standard error (stderr).

Example Hook ConfigMap
-----------------------

The following ConfigMap provides a script that modifies VM configurations by adding custom metadata to the VM's libvirt XML definition using the **onDefineDomain** hook:

.. code-block:: yaml

    apiVersion: v1
    kind: ConfigMap
    metadata:
      name: xmleditscript
    data:
      script.sh: |
        #!/bin/sh
        tempFile=`mktemp --dry-run`
        echo $4 > $tempFile
        sed -i "s|<baseBoard></baseBoard>|<baseBoard><entry name='manufacturer'>Radical Edward</entry></baseBoard>|" $tempFile
        cat $tempFile

.. note::

   The libvirt domain XML is received as the 4th argument (`$4`), and the script's standard output is used as the new domain definition to apply. This allows for dynamic modifications to the VM configuration.

Using Sidecars with VMs
------------------------

To add a hook sidecar to a VM, modify the VM manifest to include the required annotations that specify the hook configuration. The ConfigMap containing your script must be referenced in the annotations:

.. code-block:: yaml

    apiVersion: kubevirt.io/v1
    kind: VirtualMachine
    metadata:
      name: example-vm
    spec:
      template:
        metadata:
          annotations:
            hooks.kubevirt.io/hookSidecars: '[{"args": ["--version", "v1alpha2"], 
              "configMap": {"name": "xmleditscript", "key": "script.sh", "hookPath": "/usr/bin/onDefineDomain"}}]'
        spec:
          domain:
            # VM configuration...
          volumes:
          - name: config-volume
            configMap:
              name: xmleditscript


Validating the Sidecar Modifications
=====================================

After applying the sidecar configuration, you can verify that the changes have been successfully applied using several methods:

Method 1: Check VM XML from virt-launcher Pod
----------------------------------------------

1. Get the virt-launcher pod for your VM:

.. code-block:: bash

    oc get pods -n <namespace> | grep virt-launcher-<vm-name>

2. Examine the libvirt XML directly from the virt-launcher pod:

.. code-block:: bash

    oc exec virt-launcher-<vm-name>-<random-id> -n <namespace> -- virsh dumpxml 1 | grep -A3 manufacturer

3. The output should include the modified XML with the custom manufacturer entry:

.. code-block:: xml

    <entry name='manufacturer'>Radical Edward</entry>

Method 2: From Inside the VM
-----------------------------

If your modification affects data visible to the guest OS (like SMBIOS data), you can also verify from inside the VM using tools like dmidecode:

1. Connect to the VM console or SSH into the VM
2. Run dmidecode to check the baseboard manufacturer:

.. code-block:: bash

    sudo dmidecode -s baseboard-manufacturer

3. The output should show:

.. code-block:: text

    Radical Edward


References
==========

.. _kubevirt_docs:

* `KubeVirt Documentation <https://kubevirt.io/user-guide/>`_
* `OpenShift CNV Documentation <https://docs.openshift.com/container-platform/latest/virt/about-virt.html>`_
* `Kubernetes Sidecar Patterns <https://kubernetes.io/docs/concepts/workloads/pods/#how-pods-manage-multiple-containers>`_
