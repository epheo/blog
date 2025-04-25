.. meta::
   :description:
      Implement a simple block device backup system for OpenShift lab environments using BorgBackup.
   :keywords:
      Kubernetes, OpenShift, BorgBackup, backups, block devices, lab environment, containers, storage


*********************************************************
Simple Block Device Backup for OpenShift Lab Environments
*********************************************************

.. article-info::
    :date: April 25, 2025
    :read-time: 8 min read

Introduction
============

This article introduces a simple solution for backing up and restoring LVM Logical Volumes from local storage
of a Single Node OpenShift (SNO) cluster to FreeNAS using BorgBackup. While not designed for enterprise-grade
production workloads, this approach provides a practical method for protecting block storage in test
and development clusters. The solution is deliberately kept simple to allow quick setup and testing in lab environments
without the complexity of enterprise backup solutions.

Overview & Prerequisites
========================

This backup solution provides a step-by-step approach to backing up LVM Logical Volumes from a Single Node OpenShift's local storage to FreeNAS storage servers. It uses the following components:

* **BorgBackup Engine**: Provides efficient, deduplicated, and encrypted backups
* **Container Image**: A minimal image with BorgBackup and necessary tools
* **Kubernetes CronJobs**: For scheduled backup operations of local LVM volumes
* **Kubernetes Pods**: For restore operations to FreeNAS storage
* **Volume/Device Mounts**: Direct access to LVM block devices on the SNO node

.. note::
   All resources described in this article, including YAML manifests and Dockerfile, are available in the `GitHub repository <https://github.com/epheo/blog>`_.


Step 1: Prepare Your Environment
================================

Container Image
---------------

First, you'll need a container image with BorgBackup installed. The system uses a minimal Docker image based on Fedora:

.. literalinclude:: borg-container/Dockerfile
   :language: dockerfile
   :caption: Container image definition
   :linenos:

Build and push this image to your registry:

.. code-block:: bash

    cd borg-container
    podman build -t registry.example.com/borgbackup:latest .
    podman push registry.example.com/borgbackup:latest

Resource Planning
---------------------

When deploying backup and restore pods, allocate appropriate resources for optimal performance:

* **Memory**: 4Gi limit (1Gi request)
* **CPU**: 2 cores limit (500m request)

These values provide a balance between ensuring sufficient resources and maintaining efficient cluster resource utilization.

Storage Architecture
--------------------

The backup system uses two primary storage mechanisms that connect your SNO's local storage to FreeNAS:

* **Source LVM Storage**: Direct access to LVM Logical Volumes on the SNO node
* **FreeNAS Repository Storage**: iSCSI-based persistent volumes from FreeNAS to store the BorgBackup repositories

This dual-storage approach enables efficient backup of LVM volumes from your SNO node to your FreeNAS storage while maintaining the ability to perform block-level operations on raw devices.

Step 2: Configure and Run Backups
=================================

Create a CronJob to schedule regular backups of your block devices:

.. literalinclude:: windows-backup-cron.yaml
   :language: yaml
   :caption: Example backup cronjob configuration
   :emphasize-lines: 6-8,23-24
   :linenos:

Apply this configuration:

.. code-block:: bash

    kubectl apply -f backup-cronjob.yaml

To run an immediate backup:

.. code-block:: bash

    kubectl create job --from=cronjob/<backup-cronjob-name> manual-backup

.. important::
   Ensure that source block devices are properly configured and accessible to the backup pod.

Step 3: Monitor and Manage Your Backups
=======================================

Checking Backup Status
----------------------

After starting a backup job, monitor its status:

.. code-block:: bash

    kubectl get jobs
    
Example output:

.. code-block:: none

    NAME                   COMPLETIONS   DURATION   AGE
    block-backup-manual    1/1           2m15s      10m
    vm-backup-1682456400   1/1           1m32s      2h

Examining Backup Logs
----------------------

View detailed logs to confirm successful backups or troubleshoot issues:

.. code-block:: bash

    kubectl logs <pod-name>

.. tip::
   Use the ``-f`` flag (``kubectl logs -f <pod-name>``) to follow logs in real-time during backup operations.

Managing Backup Archives
------------------------

To list available backups in your repository, create a temporary pod with the same volumes:

.. code-block:: bash

    # Create a temporary pod with the backup volume and needed environment variables
    cat << EOF | kubectl apply -f -
    apiVersion: v1
    kind: Pod
    metadata:
      name: borg-inspector
    spec:
      containers:
      - name: borg-inspector
        image: registry.desku.be/epheo/borgbackup:latest
        command: ["sleep", "3600"]
        env:
        - name: BORG_UNKNOWN_UNENCRYPTED_REPO_ACCESS_IS_OK
          value: "yes"
        volumeMounts:
        - mountPath: /backup
          name: backup-volume
      volumes:
      - name: backup-volume
        persistentVolumeClaim:
          claimName: windowsdata-backup
    EOF
    
    # Wait for the pod to start
    kubectl wait --for=condition=Ready pod/borg-inspector
    
    # Access the pod and list backups
    kubectl exec -it borg-inspector -- borg list /backup
    
    # If you encounter a lock error like:
    # Failed to create/acquire the lock /backup/lock.exclusive (timeout).
    # You can break the lock with:
    kubectl exec -it borg-inspector -- borg break-lock /backup
    
    # Additional BorgBackup commands for repository management:
    # Check repository consistency
    kubectl exec -it borg-inspector -- borg check /backup
    
    # Show detailed information about the repository
    kubectl exec -it borg-inspector -- borg info /backup
    
    # List archive contents
    kubectl exec -it borg-inspector -- borg list /backup::archivename
    
    # Extract specific files from archive
    kubectl exec -it borg-inspector -- borg extract /backup::archivename path/to/file
    
    # Prune archives to save space ( /!\ DELETES archives more than 30 days old /!\)
    kubectl exec -it borg-inspector -- borg prune -v --list --keep-within=30d /backup

    # Remove the temporary pod after use
    kubectl delete pod borg-inspector

Step 4: Restore to a Local Volume
=================================

When you need to restore a backup to a local volume in the same cluster:

.. literalinclude:: windows-restore-pod.yaml
   :language: yaml
   :caption: Example restore pod configuration
   :emphasize-lines: 17
   :linenos:

Apply this configuration:

.. code-block:: bash

    kubectl apply -f restore-pod.yaml

.. important::
   Ensure that target block devices are not in use during restore operations to prevent data corruption.

Step 5: Cross-Platform Restoration Process
===============================================

This section explains how to restore backups from your FreeNAS storage to LVM Logical Volumes on your Single Node OpenShift, which is particularly useful for migration scenarios or disaster recovery of your SNO environment.

Prerequisites
---------------------

Before beginning the FreeNAS to SNO restoration, ensure you have:

* Democratic-CSI backend installed on your Single Node OpenShift cluster
* Access to your FreeNAS storage system containing the backup repositories
* Appropriate permissions to create storage resources in the target namespace


The process involves three sequential steps to connect to your existing backup repository and restore data to a new block device:

Step 5.1: Create a Reference to the Existing Backup Volume
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

First, create a PersistentVolume that references your existing FreeNAS volume containing the BorgBackup repository:

.. literalinclude:: existing-backup-pv.yaml
   :language: yaml
   :caption: existing-backup-pv.yaml
   :linenos:
   :emphasize-lines: 12,14

Apply the PersistentVolume:

.. code-block:: bash

    kubectl apply -f existing-backup-pv.yaml

Step 5.2: Create a Claim for the Backup Volume
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Next, create a PersistentVolumeClaim that binds to the volume you defined in the previous step:

.. literalinclude:: existing-backup-pvc.yaml
   :language: yaml
   :caption: existing-backup-pvc.yaml
   :linenos:
   :emphasize-lines: 9-10

Apply the PersistentVolumeClaim:

.. code-block:: bash

    kubectl apply -f existing-backup-pvc.yaml

Step 5.3: Create a Restore Pod
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Finally, create a restoration pod that will extract data from the backup repository and write it to the target device:

.. literalinclude:: restore-from-backup-pod.yaml
   :language: yaml
   :caption: restore-from-backup-pod.yaml
   :linenos:
   :emphasize-lines: 15,19-20

Apply the restore pod:

.. code-block:: bash

    kubectl apply -f restore-from-backup-pod.yaml

Step 6: Verify the Restoration
==============================

After the restore process completes, verify the integrity of the restored data:

.. code-block:: bash
   :caption: Verification commands

    # Create a temporary directory for verification
    kubectl exec -it restore-from-existing-backup -- mkdir -p /mnt/verify
    
    # Mount the restored device for verification
    kubectl exec -it restore-from-existing-backup -- mount /dev/target-block /mnt/verify
    
    # Check the contents
    kubectl exec -it restore-from-existing-backup -- ls -la /mnt/verify

.. tip::
   For block devices containing partition tables, use ``fdisk -l /dev/target-block`` 
   before mounting to verify the structure is intact.

Step 7: Directly Using Existing Block Devices with Kubernetes
================================================================

Recent OpenShift versions provide the ability to reinstall the cluster without wiping the underlying disks. 
This feature preserves existing LVM Logical Volumes, allowing you to recover existing PVs managed by LVM after reinstallation, particularly Virtual Machine disks managed by OpenShift Virtualization.

We would them make these volumes available again as PersistentVolumes in the new cluster

Identifying Available Block Devices
-----------------------------------

First, identify the block devices on your system:

.. code-block:: bash

   # From a debug pod with host access
   oc debug node/<node-name>
   chroot /host
   
   # List block devices
   lsblk
   
   # Get more detailed information about a specific device
   blkid /dev/sdX

Direct PersistentVolume Approach
--------------------------------

You can create a PersistentVolume that directly references the block device using the Local Volume static provisioner:

.. code-block:: yaml
   :caption: local-pv.yaml
   :linenos:

   apiVersion: v1
   kind: PersistentVolume
   metadata:
     name: existing-block-pv
   spec:
     capacity:
       storage: 50Gi
     volumeMode: Block  # Use Block for raw device or Filesystem for formatted
     accessModes:
       - ReadWriteOnce
     persistentVolumeReclaimPolicy: Retain
     storageClassName: local-storage
     local:
       path: /dev/sdX  # Replace with your actual device path
     nodeAffinity:
       required:
         nodeSelectorTerms:
         - matchExpressions:
           - key: kubernetes.io/hostname
             operator: In
             values:
             - sno-node-01  # Replace with your node name

Apply the PersistentVolume:

.. code-block:: bash

   kubectl apply -f local-pv.yaml

Creating a PersistentVolumeClaim
---------------------------------

Now create a PersistentVolumeClaim that will bind to your PersistentVolume:

.. code-block:: yaml
   :caption: local-pvc.yaml
   :linenos:

   apiVersion: v1
   kind: PersistentVolumeClaim
   metadata:
     name: existing-block-pvc
     namespace: my-namespace
   spec:
     volumeMode: Block  # Must match the PV's volumeMode
     accessModes:
       - ReadWriteOnce
     resources:
       requests:
         storage: 50Gi
     volumeName: existing-block-pv  # Reference the PV by name
     storageClassName: local-storage

Apply the PersistentVolumeClaim:

.. code-block:: bash

   kubectl apply -f local-pvc.yaml

Using the Block Device in a Pod
-------------------------------

You can now use the block device in a pod:

.. code-block:: yaml
   :caption: block-device-pod.yaml
   :linenos:
   :emphasize-lines: 12-14

   apiVersion: v1
   kind: Pod
   metadata:
     name: block-device-pod
     namespace: my-namespace
   spec:
     containers:
     - name: block-user
       image: registry.access.redhat.com/ubi8/ubi-minimal:latest
       command: ["sleep", "infinity"]
       volumeDevices:  # Note: volumeDevices instead of volumeMounts for Block mode
       - name: block-vol
         devicePath: /dev/xvda  # How the device will appear in the container
     volumes:
     - name: block-vol
       persistentVolumeClaim:
         claimName: existing-block-pvc

Apply this pod configuration:

.. code-block:: bash

   kubectl apply -f block-device-pod.yaml

Verification
------------

Verify that you can access and use the block device:

.. code-block:: bash

   # Check that the pod is running
   kubectl get pod -n my-namespace block-device-pod
   
   # Access the pod and verify the block device is available
   kubectl exec -it -n my-namespace block-device-pod -- lsblk
   
   # If you need to format and mount the device inside the pod
   kubectl exec -it -n my-namespace block-device-pod -- mkfs.ext4 /dev/xvda
   kubectl exec -it -n my-namespace block-device-pod -- mkdir -p /mnt/data
   kubectl exec -it -n my-namespace block-device-pod -- mount /dev/xvda /mnt/data

.. tip::
   For an existing formatted device, skip the formatting step and only mount it.

This approach bypasses the need for the LVM Operator entirely and gives you direct access to your block devices while still managing them through Kubernetes abstractions.

Resources and References
========================

The following resources provide additional information on BorgBackup and Kubernetes concepts used in this article:

* `BorgBackup Image Backup Documentation <https://borgbackup.readthedocs.io/en/stable/deployment/image-backup.html>`_
* `Kubernetes CronJob Documentation <https://kubernetes.io/docs/concepts/workloads/controllers/cron-jobs/>`_
* `Kubernetes Persistent Volumes <https://kubernetes.io/docs/concepts/storage/persistent-volumes/>`_
