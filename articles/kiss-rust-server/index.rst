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

So a container image containing a whole userland and a full-fledged webserver with all 
bells and whistles behind yet another full-fledged proxy.

Now I thought, we're in 2025 and disk space is expensive (Yes, I wrote that before it actually became true). 
An Nginx container image is at least 80MiB, If I would write my very own static web server and run it from a scratch 
container image I could go down to a few hundred KiB and save...
Let's do the maths: a 1TB NVMe is around 70Euros on Amazon (yes it was) so that's around 0.00007€ 
per MiB, assuming my container image will be around 500KiB that's a whooping 0.005 Euro 
difference, bargain !

So I decided to spend a few days of my summer holidays and go save those 0.005 Euro.

Who needs logic when you have a goal.

Anyhow, I started working on it with my friend Claude, got a functional prototype, and 
finally came back to reason: this is useless.

Unless... unless my 20 monthly visitors were too much for Nginx to handle and I needed 
a much more performant web server. Let's set a 1 Million Request per seconds target so 
if those 20 monthly visitors suddenly decided to connect at the exact same time and all 
refresh my blog page 50 000 times every seconds, they'd be safe.

So I started working again, and got to a 454KiB container image, that serves around 700K 
requests per seconds from my laptop's Intel Gen12 and 1M+ RPS on my server !

I now host my blog with it, and you, who read, are safe to refresh this page if you want.
Unless... unless the ingress controller is now the bottleneck ! Let's work on a new 
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


Architecture
=============

.. mermaid::

   flowchart LR
      subgraph startup["Startup (once)"]
         direction TB
         A["Scan static directory"] --> B["Load files into memory"]
         B --> C["Pre-generate HTTP responses\n(headers + body in one buffer)"]
         C --> D["Build FxHashMap cache"]
         D --> E["Pre-generate 304 / error\nresponse templates"]
      end

      subgraph runtime["Runtime (per request)"]
         direction TB
         F["TCP accept"] --> G["Zero-alloc HTTP parse\n(byte offsets only)"]
         G --> H{"Path lookup\nO(1) FxHashMap"}
         H -->|Hit| I["Single write_all()\npre-built response"]
         H -->|304| J["write_all()\npre-built 304"]
         H -->|Miss| K["write_all()\npre-built 404"]
      end

      startup --> runtime

At startup, KISS recursively walks the content directory, reads every file into memory,
and pre-generates a complete HTTP response buffer (``headers + body``) for each one. At
runtime, serving a request is a single ``write_all()`` of a pre-built ``Arc<[u8]>``: no
formatting, no allocation, no syscalls beyond the write itself.


Benchmarks
===========

Tests run on AMD Ryzen AI MAX+ 395 (16 cores / 32 threads) with ``wrk`` (8 threads, 10s per test).

Concurrency Scaling
--------------------

.. list-table::
   :header-rows: 1
   :widths: 15 15 15 10 15 15

   * - Connections
     - KISS (req/s)
     - nginx (req/s)
     - Ratio
     - KISS P99
     - nginx P99
   * - 10
     - 742,572
     - 559,918
     - 1.32×
     - 24μs
     - 35μs
   * - 50
     - 881,120
     - 1,030,593
     - 0.85×
     - 181μs
     - 626μs
   * - 100
     - 1,055,977
     - 946,983
     - 1.11×
     - 284μs
     - 573μs
   * - 200
     - 1,106,015
     - 906,544
     - 1.22×
     - 380μs
     - 1.46ms
   * - 500
     - 1,142,853
     - 917,053
     - 1.24×
     - 1.05ms
     - 3.12ms

KISS scales linearly up to 500 connections. P99 tail latency stays 2–3× tighter than
nginx under load.

File Size Impact
-----------------

.. list-table::
   :header-rows: 1
   :widths: 20 15 15 10 15 15

   * - File
     - KISS (req/s)
     - nginx (req/s)
     - Ratio
     - KISS P99
     - nginx P99
   * - Small (12 B)
     - 1,022,786
     - 966,781
     - 1.05×
     - 301μs
     - 556μs
   * - Medium (100 KB)
     - 516,632
     - 454,941
     - 1.13×
     - 534μs
     - 40.09ms
   * - Large (10 MB)
     - 4,557
     - 7,681
     - 0.59×
     - 132ms
     - 21ms

nginx wins on large files because ``sendfile()`` avoids copying content through
userspace. For files under ~1 MB (the typical case for static sites), KISS is faster
with dramatically better tail latency.


Stack
======

KISS is built with four crates and aggressive release optimizations:

- **tokio** (multi-threaded async): one task per connection, no thread-per-connection
  overhead. ``TCP_NODELAY`` is set on every accepted socket.
- **rustc-hash FxHashMap**: cache lookups via a hash function optimised for short keys,
  faster than the standard ``HashMap`` for URL paths.
- **Zero-allocation HTTP parser**: request lines are parsed as byte offsets into the
  read buffer, not as owned ``String``s. Per-connection buffers are reused across
  keep-alive requests via ``clear()`` instead of reallocation.
- **Pre-generated CacheEntry**: each file becomes a single ``Arc<[u8]>`` containing
  the complete HTTP response (headers + body). A separate ``Arc<[u8]>`` holds the
  pre-built ``304 Not Modified`` response with the file's ETag. HEAD requests simply
  slice the same buffer at the stored ``header_length`` offset.

.. code-block:: rust

   struct CacheEntry {
       complete_response: Arc<[u8]>,      // Headers + body, single write_all()
       header_length: usize,              // Slice point for HEAD requests
       not_modified_response: Arc<[u8]>,  // Pre-built 304
       last_modified_timestamp: SystemTime,
       etag: Arc<str>,                    // W/"size-mtime"
   }

The release binary is compiled with ``opt-level = 3``, LTO, ``codegen-units = 1``,
``panic = abort``, and symbol stripping. The target is ``x86_64-unknown-linux-musl`` for
a fully static binary that runs from a ``scratch`` container image: **no libc, no
shell, no OS**.


Security
=========

Running from ``scratch`` means no package manager, no shell, and no utilities an
attacker could use post-exploit. The full security model:

- **No OS layer**: the container contains exactly one file: the ``kiss`` binary
- **Path traversal protection**: ``..`` sequences are rejected, symlinks are skipped
  during cache building
- **Bounded requests**: configurable max request size (default 8 KB) prevents memory
  exhaustion from oversized headers
- **Rootless**: runs as non-root user (UID 65534) on Kubernetes, supports OpenShift's
  arbitrary UID assignment
- **Read-only filesystem**: compatible with ``readOnlyRootFilesystem: true``
- **Graceful shutdown**: handles SIGTERM/SIGINT for clean container termination


Quick Start
============

Extend the KISS base image with your static content:

.. code-block:: dockerfile

   FROM quay.io/epheo/kiss:latest
   COPY ./my-website/ /content/

Build and run:

.. code-block:: bash

   podman build -t my-website .
   podman run -p 8080:8080 --read-only my-website

Deploy to Kubernetes with health probes and a locked-down security context:

.. code-block:: yaml

   apiVersion: apps/v1
   kind: Deployment
   metadata:
     name: my-website
   spec:
     replicas: 3
     selector:
       matchLabels:
         app: my-website
     template:
       metadata:
         labels:
           app: my-website
       spec:
         securityContext:
           runAsNonRoot: true
           runAsUser: 65534
           runAsGroup: 65534
         containers:
         - name: kiss
           image: my-website:latest
           ports:
           - containerPort: 8080
           securityContext:
             allowPrivilegeEscalation: false
             readOnlyRootFilesystem: true
             capabilities:
               drop: [ALL]
           livenessProbe:
             httpGet:
               path: /health
               port: 8080
           readinessProbe:
             httpGet:
               path: /ready
               port: 8080

.. tip::

   On OpenShift, remove ``runAsUser`` and ``runAsGroup``: OpenShift assigns arbitrary
   UIDs with GID 0, which KISS supports out of the box.


If you are also mindful of saving some disk space and serving a ridiculous amount of 
requests per second without any guarantee, you can also try KISS.

* `GitHub project <https://github.com/epheo/kiss>`_
* `Container image on Quay.io <https://quay.io/repository/epheo/kiss>`_