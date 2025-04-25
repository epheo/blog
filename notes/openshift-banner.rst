.. meta::
   :description:
      How to set a console banner in OpenShift to display important information like the cluster name.
 
   :keywords:
      OpenShift, Console, Banner, Notification, Cluster Management

*****************************
OpenShift Console Banner
*****************************

.. article-info::
    :date: Apr 25, 2025
    :read-time: 2 min read

Adding visual indicators to your OpenShift clusters can help users quickly identify which environment they're working in, potentially preventing accidental changes in production environments.

This article demonstrates how to set a console banner in OpenShift to display important information like the cluster name or environment type.

Setting up a Console Banner
===========================

You can create a banner on the OpenShift web console by creating a ``ConsoleNotification`` custom resource:

.. code-block:: yaml

   apiVersion: console.openshift.io/v1
   kind: ConsoleNotification
   metadata:
     name: banner
   spec:
     backgroundColor: '#0f4414'  # Dark red
     color: '#ffffff'            # White text
     location: BannerTop
     text: If it ain't broke, don't fix it

Banner Customization
====================

You can customize the following aspects of the banner:

- **backgroundColor**: The background color of the banner (hex color code)
- **color**: The text color (hex color code)
- **location**: Where the banner appears. Options include:
  - ``BannerTop``: Displays at the very top of the console (most common)
  - ``BannerBottom``: Displays at the bottom of the console
  - ``BannerTopBottom``: Displays at both top and bottom of the console
  - ``AlertBanner``: Displays as a more prominent alert banner
- **text**: The message to display to users

Example Colors
--------------

.. role:: color-prod
.. role:: color-dev
.. role:: color-test
.. role:: color-staging

- Production: :color-prod:`Red (#880808)`
- Development: :color-dev:`Blue (#0066CC)`
- Testing: :color-test:`Green (#2E8B57)`
- Staging: :color-staging:`Orange (#FF8C00)`

Common Use Cases
================

- Identifying different clusters (prod, dev, test)
- Warning users about scheduled maintenance
- Highlighting important information about the environment

.. note::
   Using distinct colors for different environments helps users visually identify which cluster they're working with, reducing the risk of mistakes.

Applying the Configuration
==========================

Apply the configuration using the ``oc`` command:

.. code-block:: bash

   oc apply -f banner.yaml
   
To remove the banner:

.. code-block:: bash

   oc delete consolennotification banner
