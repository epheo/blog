.. meta::
   :description:
      Essential Podman commands and techniques for container operations
      including image squashing, systemd integration, and offline transfers.
   :keywords:
      Podman, container, rootless, systemd, squash, image, Linux

:Publish Date: 2025-04-22

Useful Podman Commands
=====================================

.. article-info::
    :date: April 22, 2025
    :read-time: 2 min read

Introduction
------------

This article provides a collection of useful Podman commands and techniques for common container operations.
Podman is a daemonless container engine that provides a Docker-compatible command line interface.

Squashing Container Images
--------------------------

Squashing container images reduces their size by combining multiple layers into one, making distribution more efficient.

.. code-block:: bash

   podman build --layers --force-rm --squash-all --tag squashedimage - <<< "FROM registry/imagetosquash"

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

Systemd Integration with Quadlet
---------------------------------

.. note::

   ``podman generate systemd`` is deprecated since Podman 4.4. Use `Quadlet
   <https://docs.podman.io/en/latest/markdown/podman-systemd.unit.5.html>`_
   instead: drop a ``.container`` unit file and systemd manages the lifecycle.

.. code-block:: bash

   # Enable user services when logged out
   loginctl enable-linger $USER

Create a Quadlet unit file:

.. code-block:: ini
   :caption: ~/.config/containers/systemd/my-app.container

   [Container]
   Image=docker.io/library/nginx:alpine
   PublishPort=8080:80
   Volume=%h/html:/usr/share/nginx/html:ro,Z

   [Service]
   Restart=always

   [Install]
   WantedBy=default.target

.. code-block:: bash

   # Reload and start
   systemctl --user daemon-reload
   systemctl --user start my-app

Rootless Networking
-------------------

Rootless containers use ``slirp4netns`` by default, with ``pasta`` as an
alternative with better performance:

.. code-block:: bash

   # Use pasta network driver (faster port forwarding)
   podman run -d --network pasta -p 8080:80 nginx:alpine

   # Create an isolated network for inter-container communication
   podman network create my-net
   podman run -d --network my-net --name db postgres:16-alpine
   podman run -d --network my-net --name app -e DB_HOST=db my-app

Multi-Container Pods
--------------------

Pods share network namespace, similar to a Kubernetes Pod:

.. code-block:: bash

   # Create a pod exposing ports
   podman pod create --name my-pod -p 8080:80 -p 3306:3306

   # Add containers to the pod (they share localhost)
   podman run -d --pod my-pod --name db \
     -e MYSQL_ROOT_PASSWORD=secret \
     docker.io/mariadb:latest

   podman run -d --pod my-pod --name web \
     docker.io/nginx:alpine

   # Generate a Kubernetes-compatible YAML from a running pod
   podman generate kube my-pod > my-pod.yaml
