.. meta::
   :description:
      Implement dual interface routing in Kubernetes using NGINX ingress controllers with externalIPs services for complete network separation between public and private services.

   :keywords:
      NGINX, ingress, dual interface, routing, Kubernetes, network separation, externalIPs, GitOps


:Publish Date: 2024-08-16

********************************************************
Dual Interface Routing with NGINX Ingress in Kubernetes
********************************************************

.. article-info::
    :date: Aug 16, 2024
    :read-time: 3 min read


While I would consider this a basic requirement I never understood why Kubernetes Ingress 
Routers didn't natively provides a way to expose private endpoints on one interface and 
public ones on a second interface (OpenShift does it quite well).

The following describes how one would implement true network separation in Kubernetes 
using dual interface routing with NGINX ingress controllers and externalIPs services and 
enable isolation between public and private services.

.. seealso::

    https://kubernetes.io/docs/concepts/services-networking/service/#externalips


Architecture Overview
======================

Our dual interface implementation consists of:

* **Public Interface (eth0)**: Routes external traffic to public services
* **Private Interface (eth1)**: Routes internal traffic to private services  
* **ExternalIPs Services**: Bind NGINX controllers to specific interface IPs
* **Ingress Class Selection**: Applications choose routing via ingress class

.. code-block:: text

   External Clients
   ├── Public Interface (168.119.158.20:80/443)
   │   └── nginx-public-external Service (externalIPs)
   │       └── nginx-ingress-public Controller
   │           ├── blog.epheo.eu (public blog)
   │           └── epheo.eu (personal site)
   │
   └── Private Interface (172.16.0.11:80/443)
       └── nginx-private-external Service (externalIPs)
           └── nginx-ingress-private Controller
               ├── argocd (GitOps management)
               └── git (Git server)

Implementation Details
======================

Network Interface Configuration
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

The implementation assumes two network interfaces on Kubernetes nodes:

.. code-block:: text

   eth0: 168.119.158.20    # Public interface (firewall: 80/443 only)
   eth1: 172.16.0.11     # Private interface (no firewall restrictions)

ExternalIPs Services Setup
~~~~~~~~~~~~~~~~~~~~~~~~~~~

Create services that bind NGINX controllers to specific interface IPs:

.. code-block:: yaml
   :caption: nginx-public-external.yaml

   apiVersion: v1
   kind: Service
   metadata:
     name: nginx-public-external
     namespace: nginx-ingress-public
     labels:
       app.kubernetes.io/name: nginx-public-external
       app.kubernetes.io/component: networking
       app.kubernetes.io/instance: nginx-external-services
       app.kubernetes.io/part-of: platform
   spec:
     type: ClusterIP
     externalIPs:
     - 168.119.158.20  # eth0 public interface
     ports:
     - port: 80
       targetPort: 80
       protocol: TCP
       name: http
     - port: 443
       targetPort: 443
       protocol: TCP
       name: https
     selector:
       app.kubernetes.io/name: ingress-nginx
       app.kubernetes.io/instance: nginx-ingress-public
       app.kubernetes.io/component: controller

.. code-block:: yaml
   :caption: nginx-private-external.yaml

   apiVersion: v1
   kind: Service
   metadata:
     name: nginx-private-external
     namespace: nginx-ingress-private
     labels:
       app.kubernetes.io/name: nginx-private-external
       app.kubernetes.io/component: networking
       app.kubernetes.io/instance: nginx-external-services
       app.kubernetes.io/part-of: platform
   spec:
     type: ClusterIP
     externalIPs:
     - 172.16.0.11  # eth1 private interface
     ports:
     - port: 80
       targetPort: 80
       protocol: TCP
       name: http
     - port: 443
       targetPort: 443
       protocol: TCP
       name: https
     selector:
       app.kubernetes.io/name: ingress-nginx
       app.kubernetes.io/instance: nginx-ingress-private
       app.kubernetes.io/component: controller

NGINX Controller Configuration
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Configure separate NGINX ingress controllers for each interface:

.. code-block:: yaml
   :caption: public-controller-values.yaml

   controller:
     name: nginx-public
     ingressClass: nginx-public
     ingressClassResource:
       name: nginx-public
       enabled: true
       default: false
       controllerValue: "k8s.io/nginx-public"
     
     # Minimal configuration for reliable operation
     config:
       use-forwarded-headers: "true"
       compute-full-forwarded-for: "true"
       use-proxy-protocol: "false"
     
     # Resource configuration
     resources:
       requests:
         cpu: 100m
         memory: 90Mi
       limits:
         cpu: 500m
         memory: 256Mi

The private controller uses an identical configuration with ``nginx-private`` replacing ``nginx-public`` and ``k8s.io/nginx-private`` as the controller value.

Application Configuration
=========================

Public Service Example
~~~~~~~~~~~~~~~~~~~~~~

Configure public-facing applications to use the public ingress class:

.. code-block:: yaml
   :caption: public-app-ingress.yaml

   apiVersion: networking.k8s.io/v1
   kind: Ingress
   metadata:
     name: epheo-eu
     namespace: epheo-eu
     annotations:
       cert-manager.io/cluster-issuer: letsencrypt-prod
   spec:
     ingressClassName: nginx-public
     tls:
       - hosts:
           - epheo.eu
         secretName: epheo-eu-tls
     rules:
       - host: epheo.eu
         http:
           paths:
             - path: /
               pathType: Prefix
               backend:
                 service:
                   name: epheo-eu
                   port:
                     number: 80


Private Service Example
~~~~~~~~~~~~~~~~~~~~~~~

Configure administrative and internal services to use the private ingress class:

.. code-block:: yaml
   :caption: argocd-ingress.yaml

   apiVersion: networking.k8s.io/v1
   kind: Ingress
   metadata:
     name: argocd-server
     namespace: argocd
     annotations:
       cert-manager.io/cluster-issuer: self-signed-issuer
   spec:
     ingressClassName: nginx-private
     tls:
       - hosts:
           - argocd.def.ms
         secretName: argocd-server-tls
     rules:
       - host: argocd.def.ms
         http:
           paths:
             - path: /
               pathType: Prefix
               backend:
                 service:
                   name: argocd-server
                   port:
                     number: 80

Verification
============

Verify the ingress controllers are running and routing correctly:

.. code-block:: bash

   # Check both controllers are running
   kubectl get pods -n nginx-ingress-public
   kubectl get pods -n nginx-ingress-private

   # Verify services have correct externalIPs
   kubectl get svc -n nginx-ingress-public nginx-public-external
   kubectl get svc -n nginx-ingress-private nginx-private-external

   # Test public routing
   curl -H "Host: epheo.eu" http://168.119.158.20

   # Test private routing
   curl -H "Host: argocd.def.ms" http://172.16.0.11

