.. meta::
   :description:
      A step-by-step guide on how to merge multiple kubeconfig files for managing multiple Kubernetes clusters efficiently.
 
   :keywords:
      Kubernetes, kubeconfig, kubectl, K8s, OpenShift, Configuration, Merge, Multiple Clusters

****************************
Merging kubeconfig Files
****************************

.. article-info::
    :date: Apr 25, 2025
    :read-time: 3 min read

When working with multiple Kubernetes or OpenShift clusters, you'll often have multiple kubeconfig files. 
Kubernetes provides tools to merge these configurations into a single file.


Prerequisites
=============

* Access to the Kubernetes or OpenShift clusters you want to manage
* Existing kubeconfig files for each cluster
* kubectl or oc command-line tools installed

Step-by-Step Merge Process
==========================

1. Backup Existing Configuration
---------------------------------

Before merging, create a backup of your existing kubeconfig file to ensure you can revert to the original configuration if needed.

.. code-block:: bash

   cp ~/.kube/config ~/.kube/config.backup

2. Set the KUBECONFIG Environment Variable
------------------------------------------

The KUBECONFIG environment variable allows you to specify multiple kubeconfig files. These files will be merged automatically by kubectl.

.. code-block:: bash

   export KUBECONFIG=~/.kube/config:/path/to/second-kubeconfig

You can add as many kubeconfig files as needed, separating them with colons (on Linux/macOS) or semicolons (on Windows).

3. Merge the Files
------------------

Use the kubectl config view command with the ``--merge`` and ``--flatten`` options to merge the configurations into a single file.

.. code-block:: bash

   kubectl config view --merge --flatten > ~/.kube/merged_kubeconfig

4. Replace the Original Configuration
-------------------------------------

Move the merged configuration to the default location.

.. code-block:: bash

   mv ~/.kube/merged_kubeconfig ~/.kube/config

5. Verify the Merged Configuration
----------------------------------

Ensure that the merged configuration works correctly by exploring and managing your contexts:

Listing Available Contexts
~~~~~~~~~~~~~~~~~~~~~~~~~~~~

To view all available contexts in your merged configuration:

.. code-block:: bash

   kubectl config get-contexts

This command displays a table with all contexts in your kubeconfig file, including:
- The current active context (marked with an asterisk \*)
- Context names
- Cluster names
- Authentication users
- Namespaces (if specified)

For a more detailed view of your entire kubeconfig:

.. code-block:: bash

   kubectl config view

Checking the Current Context
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

To see which context is currently active:

.. code-block:: bash

   kubectl config current-context

Switching Between Contexts
~~~~~~~~~~~~~~~~~~~~~~~~~~~~

To switch to a different context:

.. code-block:: bash

   kubectl config use-context <context-name>

Troubleshooting
===============

If you encounter duplicate entries or conflicts during the merge:

- Manually edit the merged kubeconfig to resolve conflicts
- Ensure unique names for clusters, contexts, and users in each original kubeconfig file
- Use the ``--flatten`` option to handle duplicates when merging

.. note::
   The merged kubeconfig file might be quite large if you're managing many clusters. Consider organizing your configs and removing outdated or unnecessary cluster entries periodically.
