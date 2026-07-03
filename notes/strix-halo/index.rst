.. meta::
   :keywords:
      vLLM, ROCm, Strix Halo, gfx1151, AMD, TheRock, Fedora, AI, GPU
   :description:
      Building vLLM from source with ROCm 7.2 nightly on AMD Strix Halo
      (gfx1151) on Fedora 43.


:Publish Date: 2026-02-15

*****************************
Running vLLM on Strix Halo
*****************************

.. article-info::
    :date: Feb 15, 2026
    :read-time: 5 min read

So I bought this machine, AMD RYZEN AI MAX+ 395 w/ Radeon 8060S and 128GB GTT RAM,
and I knew that the ecosystem was still... ongoing.
But it really felt like going back to the OpenStack early days, struggling with nightly builds, 
unreleased patches, vendor forks, etc. Maybe the issue is just Python in the end. 

In short, AMD Strix Halo (gfx1151) isn't in upstream vLLM's supported GPU list yet, so
this note walks through building vLLM against ROCm nightly (TheRock) on Fedora 43,
including the patches needed to work around missing ``amdsmi`` support.

:download:`Download the full build script <vllm.sh>`


Prerequisites
=============

.. code-block:: bash

   dnf install -y \
     python3.13 python3.13-devel \
     libatomic \
     gcc gcc-c++ make ffmpeg-free \
     aria2 \
     libdrm-devel zlib-devel openssl-devel procps-ng \
     numactl-devel gperftools-libs libibverbs-utils


Installing ROCm via TheRock nightly
====================================

AMD's `TheRock <https://github.com/ROCm/TheRock>`_ project publishes nightly
tarballs to an S3 bucket, indexed by GFX target. We grab the latest one for
``gfx1151``:

.. code-block:: bash

   GFX=gfx1151
   ROCM_PATH=/opt/rocm

   S3="https://therock-nightly-tarball.s3.amazonaws.com"
   PREFIX="therock-dist-linux-${GFX}-7"

   KEY="$(curl -s "${S3}?list-type=2&prefix=${PREFIX}" \
     | grep -oP '(?<=<Key>)[^<]+' \
     | sort -V | tail -n1)"

   aria2c -x 16 -s 16 -j 16 --file-allocation=none "${S3}/${KEY}" -o therock.tar.gz

   mkdir -p "$ROCM_PATH"
   tar xzf therock.tar.gz -C "$ROCM_PATH" --strip-components=1
   rm therock.tar.gz


Environment setup
=================

TheRock nightlies don't ship a stable bitcode path, so we locate it dynamically:

.. code-block:: bash

   BITCODE_PATH="$(find "$ROCM_PATH" -type d -name bitcode -print -quit)"

Then create a profile script so the environment is set for every shell:

.. code-block:: bash

   cat > /etc/profile.d/rocm-sdk.sh <<EOF
   export ROCM_PATH=$ROCM_PATH
   export HIP_PLATFORM=amd
   export HIP_PATH=$ROCM_PATH
   export HIP_CLANG_PATH=$ROCM_PATH/llvm/bin
   export HIP_DEVICE_LIB_PATH=$BITCODE_PATH
   export PATH=$ROCM_PATH/bin:$ROCM_PATH/llvm/bin:\$PATH
   export LD_LIBRARY_PATH=$ROCM_PATH/lib:$ROCM_PATH/lib64:$ROCM_PATH/llvm/lib:\$LD_LIBRARY_PATH
   export ROCBLAS_USE_HIPBLASLT=1
   export TORCH_ROCM_AOTRITON_ENABLE_EXPERIMENTAL=1
   export VLLM_TARGET_DEVICE=rocm
   export HIP_FORCE_DEV_KERNARG=1
   export RAY_EXPERIMENTAL_NOSET_ROCR_VISIBLE_DEVICES=1
   export LD_PRELOAD=/usr/lib64/libtcmalloc_minimal.so.4
   EOF

   source /etc/profile.d/rocm-sdk.sh

Notable variables:

- ``TORCH_ROCM_AOTRITON_ENABLE_EXPERIMENTAL``: enables experimental Triton
  kernels needed for gfx1151
- ``HIP_FORCE_DEV_KERNARG``: required for Strix Halo's memory model
- ``LD_PRELOAD=libtcmalloc_minimal``: significant inference throughput gain


Installing PyTorch from ROCm nightly
=====================================

AMD publishes per-target nightly wheels. The index URL must match the GFX
target:

.. code-block:: bash

   python -m pip install \
     --index-url "https://rocm.nightlies.amd.com/v2-staging/${GFX}/" \
     --pre torch torchaudio torchvision


Building flash-attention (ROCm fork)
=====================================

ROCm's fork of flash-attention includes AMD-specific Triton optimizations:

.. code-block:: bash

   export FLASH_ATTENTION_TRITON_AMD_ENABLE="TRUE"
   git clone https://github.com/ROCm/flash-attention.git /opt/flash-attention
   cd /opt/flash-attention && git checkout main_perf
   python setup.py install


Patching & building vLLM
=========================

vLLM probes ``amdsmi`` at import time to detect AMD GPUs,
but ``amdsmi`` doesn't know about Strix Halo yet. The patches:

1. **Stub out amdsmi in** ``vllm/platforms/__init__.py``: disable the import,
   force ``is_rocm = True``, and no-op the init/shutdown calls.
2. **Mock amdsmi in** ``vllm/platforms/rocm.py``: inject a ``MagicMock`` module
   and hardcode ``device_name = "gfx1151"`` so vLLM sees a known ROCm device.
3. **Set the GPU target in** ``CMakeLists.txt``: replace the default RDNA4
   targets with ``gfx1151``.

The build script applies these patches via an inline Python script, see
:download:`vllm.sh` for the full patch.

.. code-block:: bash

   git clone https://github.com/vllm-project/vllm.git /opt/vllm
   cd /opt/vllm

   # Apply the amdsmi patches (see vllm.sh for details)
   # ...

   # Replace default GPU targets
   sed -i "s/gfx1200;gfx1201/${GFX}/" CMakeLists.txt

   # Fedora's GCC produces ABI-incompatible extensions: use ROCm's clang
   export CC="$ROCM_PATH/llvm/bin/clang"
   export CXX="$ROCM_PATH/llvm/bin/clang++"

   export ROCM_HOME="$ROCM_PATH"
   export PYTORCH_ROCM_ARCH="$GFX"
   export HIP_ARCHITECTURES="$GFX"
   export AMDGPU_TARGETS="$GFX"
   export MAX_JOBS="4"

   export CMAKE_ARGS="-DROCM_PATH=$ROCM_PATH -DHIP_PATH=$ROCM_PATH \
     -DAMDGPU_TARGETS=$GFX -DHIP_ARCHITECTURES=$GFX"

   python -m pip wheel --no-build-isolation --no-deps -w /tmp/dist -v .
   python -m pip install /tmp/dist/*.whl


bitsandbytes (ROCm fork)
=========================

For quantized model support, build the ROCm-enabled bitsandbytes fork:

.. code-block:: bash

   export CMAKE_PREFIX_PATH="$ROCM_PATH"
   git clone -b rocm_enabled_multi_backend \
     https://github.com/ROCm/bitsandbytes.git /opt/bitsandbytes
   cd /opt/bitsandbytes

   cmake -S . \
     -DGPU_TARGETS="$GFX" \
     -DBNB_ROCM_ARCH="$GFX" \
     -DCOMPUTE_BACKEND=hip

   make -j"$(nproc)"
   python -m pip install . --no-build-isolation --no-deps
