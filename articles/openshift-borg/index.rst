.. meta::
   :description:
      A simple block device backup system for OpenShift labs using BorgBackup.
   :keywords:
      borgbackup, kubernetes, cronjob, persistent volumes, deduplication, incremental, backup


*********************************************************
Simple Block Device Backup for OpenShift Lab Environments
*********************************************************

.. article-info::
    :date: April 25, 2025
    :read-time: 8 min read

Introduction
============

Like the Borg collective from Star Trek assimilates technology, BorgBackup assimilates your data.

This article shows how to back up and restore LVM Logical Volumes from local storage to FreeNAS using BorgBackup.
While not for enterprise production workloads, this method works well for lab environments.


Overview & Prerequisites
========================

This backup solution backs up LVM Logical Volumes from Single Node OpenShift local storage to FreeNAS servers using:

* **BorgBackup**: For efficient, deduplicated, encrypted backups
* **Container Image**: Minimal image with BorgBackup and required tools
* **Kubernetes CronJobs**: For scheduled backups of local LVM volumes
* **Kubernetes Pods**: For restores to FreeNAS storage
* **Volume/Device Mounts**: Direct access to LVM block devices on the SNO node

.. note::
   All resources in this article are available in the `GitHub repository <https://github.com/epheo/blog>`_.


Step 1: Prepare Your Environment
================================

Container Image
---------------

Create a container image with BorgBackup:

.. literalinclude:: borg-container/Dockerfile
   :language: dockerfile
   :caption: Container image definition
   :linenos:

Build and push the image:

.. code-block:: bash

    cd borg-container
    podman build -t registry.example.com/borgbackup:latest .
    podman push registry.example.com/borgbackup:latest

Resource Planning
---------------------

Allocate resources for backup and restore pods:

* **Memory**: 4Gi limit (1Gi request)
* **CPU**: 2 cores limit (500m request)

These values balance performance with efficient resource usage.

Storage Architecture
--------------------

The backup system uses two storage mechanisms:

* **Source LVM Storage**: Direct access to LVM Logical Volumes on the SNO node
* **FreeNAS Repository Storage**: iSCSI-based persistent volumes for BorgBackup repositories

This approach enables efficient backup of LVM volumes to FreeNAS while maintaining block-level operations.

Step 2: Configure and Run Backups
=================================

Create a CronJob for regular backups:

.. literalinclude:: windows-backup-cron.yaml
   :language: yaml
   :caption: Example backup cronjob configuration
   :emphasize-lines: 6-8,23-24
   :linenos:

Apply the configuration:

.. code-block:: bash

    kubectl apply -f backup-cronjob.yaml

Run an immediate backup:

.. code-block:: bash

    kubectl create job --from=cronjob/<backup-cronjob-name> manual-backup

.. important::
   Ensure source block devices are accessible to the backup pod.

Step 3: Monitor and Manage Your Backups
=======================================

Checking Backup Status
----------------------

Monitor backup job status:

.. code-block:: bash

    kubectl get jobs
    
Example output:

.. code-block:: none

    NAME                   COMPLETIONS   DURATION   AGE
    block-backup-manual    1/1           2m15s      10m
    vm-backup-1682456400   1/1           1m32s      2h

Examining Backup Logs
----------------------

View logs to confirm success or troubleshoot:

.. code-block:: bash

    kubectl logs <pod-name>

.. tip::
   Use ``kubectl logs -f <pod-name>`` to follow logs in real-time.

Managing Backup Archives
------------------------

List available backups:

.. code-block:: bash

    # Create a temporary pod with the backup volume
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
    
    # List backups
    kubectl exec -it borg-inspector -- borg list /backup
    
    # Break a lock if needed:
    kubectl exec -it borg-inspector -- borg break-lock /backup
    
    # Additional commands:
    # Check repository 
    kubectl exec -it borg-inspector -- borg check /backup
    
    # Show repository info
    kubectl exec -it borg-inspector -- borg info /backup
    
    # List archive contents
    kubectl exec -it borg-inspector -- borg list /backup::archivename
    
    # Extract files
    kubectl exec -it borg-inspector -- borg extract /backup::archivename path/to/file
    
    # Prune old archives
    kubectl exec -it borg-inspector -- borg prune -v --list --keep-within=30d /backup

    # Remove the temporary pod
    kubectl delete pod borg-inspector

Step 4: Restore to a Local Volume
=================================

Restore a backup to a local volume:

.. literalinclude:: windows-restore-pod.yaml
   :language: yaml
   :caption: Example restore pod configuration
   :emphasize-lines: 17
   :linenos:

Apply the configuration:

.. code-block:: bash

    kubectl apply -f restore-pod.yaml

.. important::
   Ensure target block devices are not in use during restore.

Step 5: Cross-Platform Restoration Process
===============================================

This section explains how to restore backups from FreeNAS to LVM Logical Volumes on Single Node OpenShift.

Prerequisites
---------------------

Before starting:

* Install Democratic-CSI backend on your SNO cluster
* Ensure access to FreeNAS storage with the backup repositories
* Verify permissions to create storage resources in the target namespace


The process involves three steps:

Step 5.1: Create a Reference to the Existing Backup Volume
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Create a PersistentVolume referencing your FreeNAS volume:

.. literalinclude:: existing-backup-pv.yaml
   :language: yaml
   :caption: existing-backup-pv.yaml
   :linenos:
   :emphasize-lines: 12,14

Apply it:

.. code-block:: bash

    kubectl apply -f existing-backup-pv.yaml

Step 5.2: Create a Claim for the Backup Volume
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Create a PersistentVolumeClaim:

.. literalinclude:: existing-backup-pvc.yaml
   :language: yaml
   :caption: existing-backup-pvc.yaml
   :linenos:
   :emphasize-lines: 9-10

Apply it:

.. code-block:: bash

    kubectl apply -f existing-backup-pvc.yaml

Step 5.3: Create a Restore Pod
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Create a restoration pod:

.. literalinclude:: restore-from-backup-pod.yaml
   :language: yaml
   :caption: restore-from-backup-pod.yaml
   :linenos:
   :emphasize-lines: 15,19-20

Apply it:

.. code-block:: bash

    kubectl apply -f restore-from-backup-pod.yaml

Step 6: Verify the Restoration
==============================

Verify restored data:

.. code-block:: bash
   :caption: Verification commands

    # Create verification directory
    kubectl exec -it restore-from-existing-backup -- mkdir -p /mnt/verify
    
    # Mount the restored device
    kubectl exec -it restore-from-existing-backup -- mount /dev/target-block /mnt/verify
    
    # Check contents
    kubectl exec -it restore-from-existing-backup -- ls -la /mnt/verify

.. tip::
   For block devices with partition tables, use ``fdisk -l /dev/target-block`` 
   before mounting.

Step 7: Directly Using Existing Block Devices with Kubernetes
================================================================

Recent OpenShift versions can reinstall without wiping disks, preserving LVM Logical Volumes for recovery after reinstallation.

Identifying Available Block Devices
-----------------------------------

Identify block devices:

.. code-block:: bash

   # From a debug pod
   oc debug node/<node-name>
   chroot /host
   
   # List devices
   lsblk
   
   # Get device info
   blkid /dev/sdX

Direct PersistentVolume Approach
--------------------------------

Create a PersistentVolume referencing the block device:

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
       path: /dev/sdX  # Replace with your device path
     nodeAffinity:
       required:
         nodeSelectorTerms:
         - matchExpressions:
           - key: kubernetes.io/hostname
             operator: In
             values:
             - sno-node-01  # Replace with your node name

Apply it:

.. code-block:: bash

   kubectl apply -f local-pv.yaml

Creating a PersistentVolumeClaim
---------------------------------

Create a PersistentVolumeClaim:

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

Apply it:

.. code-block:: bash

   kubectl apply -f local-pvc.yaml

Using the Block Device in a Pod
-------------------------------

Use the block device in a pod:

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
       volumeDevices:  # Use volumeDevices for Block mode
       - name: block-vol
         devicePath: /dev/xvda  # Device path in container
     volumes:
     - name: block-vol
       persistentVolumeClaim:
         claimName: existing-block-pvc

Apply it:

.. code-block:: bash

   kubectl apply -f block-device-pod.yaml

Verification
------------

Verify access to the block device:

.. code-block:: bash

   # Check pod status
   kubectl get pod -n my-namespace block-device-pod
   
   # Verify block device
   kubectl exec -it -n my-namespace block-device-pod -- lsblk
   
   # Format and mount if needed
   kubectl exec -it -n my-namespace block-device-pod -- mkfs.ext4 /dev/xvda
   kubectl exec -it -n my-namespace block-device-pod -- mkdir -p /mnt/data
   kubectl exec -it -n my-namespace block-device-pod -- mount /dev/xvda /mnt/data

.. tip::
   Skip formatting for existing formatted devices.

This approach gives direct access to block devices while managing them through Kubernetes.

Resources and References
========================

Additional resources:

* `BorgBackup Image Backup Documentation <https://borgbackup.readthedocs.io/en/stable/deployment/image-backup.html>`_
* `Kubernetes CronJob Documentation <https://kubernetes.io/docs/concepts/workloads/controllers/cron-jobs/>`_
* `Kubernetes Persistent Volumes <https://kubernetes.io/docs/concepts/storage/persistent-volumes/>`_
