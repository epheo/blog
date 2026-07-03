#!/usr/bin/env bash
set -euo pipefail

# Build vLLM + ROCm nightly on AMD Strix Halo (gfx1151) / Fedora 43
# Strix Halo isn't in upstream vLLM's supported GPU list, this script
# patches around amdsmi detection and hardcodes the GPU target.

GFX=gfx1151
ROCM_PATH=/opt/rocm

dnf install -y \
  python3.13 python3.13-devel \
  libatomic \
  gcc gcc-c++ make ffmpeg-free \
  aria2 \
  libdrm-devel zlib-devel openssl-devel procps-ng \
  numactl-devel gperftools-libs libibverbs-utils

# TheRock nightly: S3 bucket listing > find latest tarball > download
S3="https://therock-nightly-tarball.s3.amazonaws.com"
PREFIX="therock-dist-linux-${GFX}-7"

KEY="$(curl -s "${S3}?list-type=2&prefix=${PREFIX}" \
  | grep -oP '(?<=<Key>)[^<]+' \
  | sort -V | tail -n1)"

if [ -z "$KEY" ]; then
    echo "Error: Could not find tarball for $PREFIX" >&2
    exit 1
fi

echo "Downloading: ${KEY}"
aria2c -x 16 -s 16 -j 16 --file-allocation=none "${S3}/${KEY}" -o therock.tar.gz

mkdir -p "$ROCM_PATH"
tar xzf therock.tar.gz -C "$ROCM_PATH" --strip-components=1
rm therock.tar.gz

# TheRock nightlies don't have a stable bitcode path, we find it dynamically
BITCODE_PATH="$(find "$ROCM_PATH" -type d -name bitcode -print -quit)"
if [ -z "$BITCODE_PATH" ]; then
    echo "Error: No bitcode directory found under $ROCM_PATH" >&2
    exit 1
fi

# Runtime environment for interactive shells
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

# Reuse runtime env for the build
source /etc/profile.d/rocm-sdk.sh

# Python venv
/usr/bin/python3.13 -m venv /opt/venv
export VIRTUAL_ENV=/opt/venv
export PATH=/opt/venv/bin:$PATH
export PIP_NO_CACHE_DIR=1
printf 'source /opt/venv/bin/activate\n' > /etc/profile.d/venv.sh
python -m pip install --upgrade pip wheel packaging "setuptools<80.0.0"

# PyTorch from TheRock nightly, we must match the GFX target
python -m pip install \
  --index-url "https://rocm.nightlies.amd.com/v2-staging/${GFX}/" \
  --pre torch torchaudio torchvision

# ROCm fork of flash-attention with AMD perf optimizations
(
  export FLASH_ATTENTION_TRITON_AMD_ENABLE="TRUE"
  git clone https://github.com/ROCm/flash-attention.git /opt/flash-attention
  cd /opt/flash-attention && git checkout main_perf
  python setup.py install
)
rm -rf /opt/flash-attention

# vLLM doesn't support Strix Halo (no amdsmi driver), we patch around it
git clone https://github.com/vllm-project/vllm.git /opt/vllm
cd /opt/vllm

python - <<'PYEOF'
import re
from pathlib import Path

# Patch __init__.py: amdsmi doesn't support Strix Halo yet,
# so we stub it out and force ROCm detection to True.
p = Path('vllm/platforms/__init__.py')
txt = p.read_text()
txt = txt.replace('import amdsmi', '# import amdsmi')
txt = re.sub(r'is_rocm = .*', 'is_rocm = True', txt)
txt = re.sub(r'if len\(amdsmi\.amdsmi_get_processor_handles\(\)\) > 0:', 'if True:', txt)
txt = txt.replace('amdsmi.amdsmi_init()', 'pass')
txt = txt.replace('amdsmi.amdsmi_shut_down()', 'pass')
p.write_text(txt)

# Patch rocm.py: mock amdsmi entirely, hardcode device identity
# so vLLM sees a known ROCm device instead of failing at runtime.
p = Path('vllm/platforms/rocm.py')
txt = p.read_text()
header = 'import sys\nfrom unittest.mock import MagicMock\nsys.modules["amdsmi"] = MagicMock()\n'
txt = header + txt
txt = re.sub(r'device_type = .*', 'device_type = "rocm"', txt)
txt = re.sub(r'device_name = .*', 'device_name = "gfx1151"', txt)
txt += '\n    def get_device_name(self, device_id: int = 0) -> str:\n        return "AMD-gfx1151"\n'
p.write_text(txt)

print('Successfully patched vLLM for Strix Halo')
PYEOF
sed -i "s/gfx1200;gfx1201/${GFX}/" CMakeLists.txt

# Build vLLM wheel
# setuptools-scm, scikit-build-core, pybind11 are build-only deps not installed earlier
python -m pip install --upgrade cmake ninja numpy "setuptools-scm>=8" scikit-build-core pybind11

# Build-only vars (runtime env already sourced from profile.d)
export ROCM_HOME="$ROCM_PATH"
export PYTORCH_ROCM_ARCH="$GFX"
export HIP_ARCHITECTURES="$GFX"
export AMDGPU_TARGETS="$GFX"
export MAX_JOBS="4"

# Fedora's GCC produces ABI-incompatible extensions, we use ROCm's clang
export CC="$ROCM_PATH/llvm/bin/clang"
export CXX="$ROCM_PATH/llvm/bin/clang++"

export CMAKE_ARGS="-DROCM_PATH=$ROCM_PATH -DHIP_PATH=$ROCM_PATH -DAMDGPU_TARGETS=$GFX -DHIP_ARCHITECTURES=$GFX"

echo "Compiling with bitcode: $HIP_DEVICE_LIB_PATH"
python -m pip wheel --no-build-isolation --no-deps -w /tmp/dist -v .
python -m pip install /tmp/dist/*.whl

python -m pip install ray

# bitsandbytes ROCm fork with quantization support
(
  export CMAKE_PREFIX_PATH="$ROCM_PATH"
  git clone -b rocm_enabled_multi_backend https://github.com/ROCm/bitsandbytes.git /opt/bitsandbytes
  cd /opt/bitsandbytes

  cmake -S . \
    -DGPU_TARGETS="$GFX" \
    -DBNB_ROCM_ARCH="$GFX" \
    -DCOMPUTE_BACKEND=hip

  make -j"$(nproc)"
  python -m pip install . --no-build-isolation --no-deps
)

# Cleanup build artifacts
rm -rf /opt/vllm /opt/bitsandbytes /tmp/dist
find /opt/venv -type f -name "*.so" -exec strip -s {} + 2>/dev/null || true
find /opt/venv -type d -name "__pycache__" -prune -exec rm -rf {} + || true

# Pinned: vLLM requires transformers >=5.0 but pip resolver picks an older one
python -m pip install transformers==5.0.0

# Runtime shell config
printf 'ulimit -S -c 0\n' > /etc/profile.d/90-nocoredump.sh
chmod 0644 /etc/profile.d/*.sh
chmod -R a+rX /opt
