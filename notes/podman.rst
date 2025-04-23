Useful Podman Commands
=====================================

.. article-info::
    :date: April 22, 2025
    :read-time: 5 min read

Introduction
------------

This article provides a collection of useful Podman commands and techniques for common container operations.
Podman is a daemonless container engine that provides a Docker-compatible command line interface.

Squashing Container Images
--------------------------

Squashing container images reduces their size by combining multiple layers into one, making distribution more efficient.

.. code-block:: bash

   podman build --layers --force-rm --squash-all --tag squashedimage - <<< "FROM regsitry/imagetosquash"

Container Run Commands
----------------------

Here are several useful patterns for running containers with Podman:

Running a Gollum wiki server:

.. code-block:: bash

   podman run --detach --name gollum --security-opt label=disable --userns=keep-id \
     -v /srv/wiki:/wiki -p 4567:4567 gollumwiki/gollum:master --default-keybind vim

Running a container with host networking:

.. code-block:: bash

   podman run -d --network host -v /var/log/sshoney/:/root/logs/ --name sshoney 97f3876877e2

Running a MariaDB container in a pod:

.. code-block:: bash

   podman run --detach --pod $POD_NAME \
     -e MYSQL_ROOT_PASSWORD=$DB_PASS \
     -e MYSQL_PASSWORD=$DB_PASS \
     -e MYSQL_DATABASE=$DB_NAME \
     -e MYSQL_USER=$DB_USER \
     --name $CONTAINER_NAME_DB \
     -v "$PWD/database":/var/lib/mysql docker.io/mariadb:latest

Running a WordPress container in a pod:

.. code-block:: bash

   podman run --detach --pod $POD_NAME \
     -e WORDPRESS_DB_HOST=127.0.0.1:3306 \
     -e WORDPRESS_DB_NAME=$DB_NAME \
     -e WORDPRESS_DB_USER=$DB_USER \
     -e WORDPRESS_DB_PASSWORD=$DB_PASS \
     --name $CONTAINER_NAME_WP \
     -v "$PWD/html":/var/www/html docker.io/wordpress

Image Transfer Between Systems
------------------------------

When direct registry access is unavailable, you can save and load images for transfer:

.. code-block:: bash

   podman image save 97f3876877e2 -o 97f3876877e2.tgz
   podman load --input 97f3876877e2.tgz

Systemd Integration
-------------------

Running containers as systemd services allows them to persist even when the user is logged out:

.. code-block:: bash

   # Enable executing processes with logged out shell
   loginctl enable-linger user
   
   # Move to user systemd directory
   cd ~/.config/systemd/user/
   
   # Generate systemd files for container
   podman generate systemd --restart-policy=always -t 1 --name container_name --files
   
   # Enable and start the service
   systemctl --user enable container-container_name.service

