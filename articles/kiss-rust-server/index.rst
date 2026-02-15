.. meta::
   :description:
      Fast and simple static file server written in Rust for Kubernetes deployments with zero disk I/O, minimal memory footprint, and reduced attack surface.

   :keywords:
      Rust, static server, Kubernetes, performance, security, container, KISS, web server, HTTP


:Publish Date: 2025-08-16

******************************
How this blog is served to you
******************************

.. article-info::
    :date: Aug 16, 2025
    :read-time: 5 min read


This blog is just static files, served from a container, behind a Kubernetes Ingress Controller.

So a container image containing a whole userland and a fullfledged webserver with all 
bells and whistle behind yet another fullfledged proxy.

Now I thought, we're in 2025 and disk space is expensive (Yes, I wrote that before it actually became true). 
An Nginx container image is at least 80MiB, If I would write my very own static web server and run it from a scratch 
container image I could go down to a few hundred KiB and save...
Let's do the maths: a 1TB NVMe is around 70Euros on Amazon (yes it was) so that's around 0.00007€ 
per MiB, assuming my container image will be around 500KiB that's a whooping 0.005 Euro 
difference, bargain !

So I decided to spend a few days of my summer holidays and go save those 0.005 Euro.

Who need logic when you have a goal.

Anyhow, I started working on it with my friend Claude, got a functionnal prototype, and 
finaly came back to reason: this is useless.

Unless... unless my 20 monthly visitors were too much for Nginx to handle and I needed 
a much more performant web server. Let's set a 1 Million Request per seconds target so 
if those 20 monthly visitors suddenly decided to connect at the exact same time and all 
refresh my blog page 50 000 times every seconds, they'd be safe.

So I started working again, and got to a 454KiB container image, that serves around 700K 
requests per seconds from my laptop's Intel Gen12 and 1M+ RPS on my server !

I now host my blog with it, and you, who read, are safe to refresh this page if you want.
Unless... unless the ingress controler is now the bottleneck ! Let's work on a new 
K8S Ingress Controller (or Gateway API) that implements io_uring and use eBPF.

Details
========

KISS (that's its name) for "Kubernetes Instant Static Server" is taking some shortcuts 
to achieve its goals.

The first and more important one is **no disk I/O**, all content is pre-loaded in RAM 
and all requests are pre-generated at startup time.

**Traditional Static Servers** (nginx, Apache):

- Read files from disk per request
- Generate HTTP headers per request
- Multiple system calls per response
- Filesystem caching complexity

**KISS Approach**:

- All files loaded into memory at startup
- HTTP responses pre-generated once
- Single write() system call per request
- Zero runtime filesystem operations

If you are also mindfull of saving some disk space and serving a ridiculous amount of 
request per seconds without any guaranty, you can also try KISS.

* `GitHub project <https://github.com/epheo/kiss>`_
* `Container image on Quay.io <https://quay.io/repository/epheo/kiss>`_