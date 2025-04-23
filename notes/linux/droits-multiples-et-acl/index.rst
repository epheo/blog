Advanced File Permissions with ACL on Linux
=======================================================

.. article-info::
    :date: Aug 06, 2010
    :read-time: 10 min read

Traditional Unix file permissions have a significant limitation: they don't allow us to grant different 
access levels to multiple users or groups simultaneously - such as read/write access for some groups 
while restricting others to read-only access.

This is where Access Control Lists (ACLs) come in. ACLs provide a more flexible permission system 
by allowing multiple access rules per file or directory. Although ACLs come pre-installed on many 
modern Linux distributions, knowing how to use them effectively remains essential, especially for 
scenarios like file sharing with Samba or managing multi-user environments.

Understanding the Difference: Traditional Permissions vs. ACLs
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Before diving into ACLs, let's compare them with traditional Unix permissions:

.. list-table::
   :header-rows: 1
   :widths: 30 35 35

   * - Feature
     - Traditional Unix Permissions
     - Access Control Lists (ACLs)
   * - Permission Structure
     - Simple rwx for owner, group, others
     - Multiple permission entries for different users/groups
   * - Permission Granularity
     - Limited to three entities
     - Unlimited entities with specific permissions
   * - Inheritance Control
     - Limited (primarily through umask)
     - Explicit inheritance with default ACLs
   * - Management Complexity
     - Simple to understand and manage
     - More complex but much more flexible
   * - Command Tools
     - chmod, chown, chgrp
     - getfacl, setfacl
   * - Windows Compatibility
     - Limited
     - Advanced support for Samba/CIFS sharing

By understanding these differences, you can make informed decisions about when to use traditional permissions versus ACLs for your file security needs.

Practical Use Case
~~~~~~~~~~~~~~~~~~

Let's consider a Samba file sharing setup in a small business with a directory called "ProjectDocs".
In this scenario:

- The manager needs full control over ProjectDocs
- The developers need read and execute permissions
- The clients should only have read-only access

This is a perfect case where we need to manage the directory permissions with ACLs, as standard Unix 
permissions would not allow this level of granular control.

Implementing Our Use Case
~~~~~~~~~~~~~~~~~~~~~~~~~

Let's implement the scenario described above with specific commands. Assuming you've already created a directory called "ProjectDocs":

.. code-block:: bash

    # Create the directory and test files
    mkdir -p /data/ProjectDocs
    touch /data/ProjectDocs/report.doc
    touch /data/ProjectDocs/specs.pdf
    
    # Set basic permissions first
    sudo chown manager:managers /data/ProjectDocs
    sudo chmod 750 /data/ProjectDocs
    
    # Grant full access to the manager
    sudo setfacl -m u:manager:rwx /data/ProjectDocs
    
    # Set read and execute permissions for the developers group
    sudo setfacl -m g:developers:rx /data/ProjectDocs
    
    # Set read-only permissions for the clients group
    sudo setfacl -m g:clients:r /data/ProjectDocs
    
    # Set default ACLs so new files inherit these permissions
    sudo setfacl -m d:u:manager:rwx /data/ProjectDocs
    sudo setfacl -m d:g:developers:rx /data/ProjectDocs
    sudo setfacl -m d:g:clients:r /data/ProjectDocs
    
    # Apply ACLs recursively to existing files
    sudo setfacl -R -m u:manager:rwx /data/ProjectDocs
    sudo setfacl -R -m g:developers:rx /data/ProjectDocs
    sudo setfacl -R -m g:clients:r /data/ProjectDocs

After executing these commands, the directory structure will have the exact permissions needed for our scenario:
- Manager has full control (read, write, execute)
- Developers can read and execute files, but not modify them
- Clients can only read the files
- All new files created in the directory will automatically inherit these permissions

You can verify the configuration with:

.. code-block:: bash

    getfacl /data/ProjectDocs

Installation
~~~~~~~~~~~~

On most modern Linux distributions, ACL support is pre-installed. If not, you can install it using your package manager:

For Red Hat-based systems:

.. code-block:: bash

    sudo dnf install acl

For Debian-based systems:

.. code-block:: bash

    sudo apt install acl

Enabling ACL Support
~~~~~~~~~~~~~~~~~~~~

Most modern Linux filesystems (ext4, XFS, Btrfs) have ACL support enabled by default. However, if you need to explicitly enable it, you'll need to modify the filesystem mount options.

First, identify the partition you want to modify. You can use the following command to list your mounted filesystems:

.. code-block:: bash

    df -h

Let's say we need to enable ACLs on ``/dev/nvme0n1p3`` mounted at ``/data``.

Edit the ``/etc/fstab`` file:

.. code-block:: bash
    
    sudo nano /etc/fstab

Add the ``acl`` option to your partition's mount options:

.. code-block:: bash
    
    /dev/nvme0n1p3    /data    ext4    defaults,acl    0    2

To apply the changes without rebooting:

.. code-block:: bash
    
    sudo mount -o remount,acl /data

Note: On most modern Linux systems with ext4, XFS, or Btrfs filesystems, ACL support is enabled by default, so this step may not be necessary.

Verifying ACL Support
~~~~~~~~~~~~~~~~~~~~~

To confirm that your filesystem supports ACLs, you can use one of these methods:

.. code-block:: bash

    # Method 1: Check filesystem capabilities 
    sudo tune2fs -l /dev/nvme0n1p3 | grep "Default mount options"
    
    # Method 2: Check if the current mount has ACL support
    mount | grep "/data" | grep "acl"
    
    # Method 3: Test if you can set an ACL (if this succeeds, ACLs are supported)
    touch /data/test_acl
    setfacl -m u:nobody:r /data/test_acl

Configuring ACLs for Files and Directories
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

There are two main commands for working with ACLs: ``getfacl`` and ``setfacl``.

The ``getfacl`` command lists ACL permissions:

.. code-block:: bash

    getfacl filename

It works similar to ``ls -l`` but provides more detailed information specific to ACLs. For example, to check permissions on a file named ``project-report.pdf``:

.. code-block:: bash

    getfacl project-report.pdf

The ``setfacl`` command configures ACL permissions for a file or directory. Its basic syntax is:

.. code-block:: bash

    setfacl -[option] [specification] filename

The command can be broken down into these components:

- **Options**: 
  - ``-m`` to add or modify a rule
  - ``-b`` to remove all ACL entries
  - ``-x`` to remove specific ACL entries

- **Specification**: ``[d:]type:name:permissions``
  - ``d:`` (optional) - if present, applies to default ACLs (used for directories)
  - ``type`` - can be ``u`` (user), ``g`` (group), or ``o`` (other)
  - ``name`` - username or group name (not needed for "other")
  - ``permissions`` - any combination of ``r`` (read), ``w`` (write), and ``x`` (execute)

Understanding ACL Masks
~~~~~~~~~~~~~~~~~~~~~~~

One of the most important concepts in Linux ACLs is the "mask". The mask defines the maximum permissions that can be granted by any ACL entry for a file or directory. Think of it as an upper bound for permissions.

.. code-block:: text

    # Example ACL with mask
    user::rw-        # Owner has read-write
    user:alex:rwx    # User alex has read-write-execute, but...
    group::r--       # Group owner has read-only
    mask::r--        # The mask restricts to read-only!
    other::---       # Others have no permissions

In this example, despite giving alex rwx permissions, the effective permissions will be r--, because the mask restricts the maximum permissions to read-only.

To explicitly set the mask value:

.. code-block:: bash

    # Set the mask to allow read and execute
    setfacl -m m::rx project-report.pdf

The mask is automatically recalculated when you add or modify ACL entries, unless you use the ``--no-mask`` option with setfacl.

Examples of ACL Usage
~~~~~~~~~~~~~~~~~~~~~

1. Give write permission to user "alex" on a file:

.. code-block:: bash
    
    setfacl -m u:alex:w project-report.pdf

2. Give read and execute permissions to the "developers" group:

.. code-block:: bash
    
    setfacl -m g:developers:rx project-report.pdf

3. Remove all ACL entries from a file:

.. code-block:: bash
    
    setfacl -b project-report.pdf

4. Apply ACLs recursively to a directory and all its contents:

.. code-block:: bash
    
    setfacl -R -m g:developers:rx ProjectDocs/

5. Set default ACLs on a directory (new files created in this directory will inherit these ACLs):

.. code-block:: bash
    
    setfacl -m d:g:developers:rx ProjectDocs/

6. Give read permission to others (all users not specifically mentioned):

.. code-block:: bash
    
    setfacl -m o::r project-report.pdf

7. View current ACL settings:

.. code-block:: bash
    
    getfacl project-report.pdf

8. Remove a specific ACL entry (remove just alex's permissions):

.. code-block:: bash

    setfacl -x u:alex project-report.pdf

9. Copy ACLs from one file to another:

.. code-block:: bash

    getfacl source_file.txt | setfacl --set-file=- destination_file.txt

The output might look like:

.. code-block:: text

    # file: project-report.pdf
    # owner: manager
    # group: admin
    user::rw-
    user:alex:rw-
    group::r--
    group:developers:r-x
    mask::rwx
    other::r--

Troubleshooting ACLs
~~~~~~~~~~~~~~~~~~~~

When working with ACLs, you might encounter some common issues. Here are solutions for the most frequent problems:

1. **ACL Commands Not Working**

   Verify your filesystem supports and has ACLs enabled:

   .. code-block:: bash

       tune2fs -l /dev/nvme0n1p3 | grep "Default mount options"

   Check if the ACL package is installed:

   .. code-block:: bash

       which getfacl

2. **Permission Denied Errors**

   Ensure you have sufficient permissions (usually requires root or ownership):

   .. code-block:: bash

       # Check your permissions on the file/directory
       ls -la /path/to/file
       
       # Use sudo if needed
       sudo setfacl -m u:user:rw /path/to/file

3. **ACLs Not Being Applied**

   Check if there's a restrictive mask:

   .. code-block:: bash

       getfacl /path/to/file | grep mask
       
       # Set a more permissive mask if needed
       setfacl -m m::rwx /path/to/file

4. **ACLs Lost After Copying Files**

   Use the correct copy command to preserve ACLs:

   .. code-block:: bash

       # Use cp with the -a (archive) option
       cp -a source_file destination_file
       
       # Or use rsync
       rsync -av --acls source_file destination_file

5. **Debugging Complex ACL Issues**

   For more complex issues, use verbose mode with ACL commands:

   .. code-block:: bash

       setfacl -v -m u:user:rw /path/to/file

Working with ACLs in Samba Shares
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

When using Samba to share files with Windows systems, you can manage ACLs through Windows File Explorer. This provides a familiar graphical interface for Windows users while maintaining the security controls you've established.

To enable this functionality in your Samba configuration, edit ``/etc/samba/smb.conf`` and ensure these options are set:

.. code-block:: ini

    [global]
    map acl inherit = yes
    store dos attributes = yes
    
    [ProjectDocs]
    path = /data/ProjectDocs
    read only = no
    acl_xattr:ignore system acls = yes
    inherit acls = yes

This configuration allows Windows clients to modify the ACLs through the familiar Windows security dialog, providing a seamless experience across platforms.

Conclusion
~~~~~~~~~~

Access Control Lists provide a powerful way to manage complex permission requirements that go beyond the traditional Unix permission model. By understanding how to use ``getfacl`` and ``setfacl``, you can create sophisticated permission structures that meet the needs of multi-user environments while maintaining proper security controls.
