#!/bin/bash
# Path: articles/kubernetes-from-scratch/worker.sh

source _common.sh

# Prerequisites

sudo dnf install -y socat conntrack ipset 

sudo swapoff -a

# Create the installation directories

sudo mkdir -p \
  /etc/cni/net.d \
  /opt/cni/bin \
  /var/lib/kubelet \
  /var/lib/kube-proxy \
  /var/lib/kubernetes \
  /var/run/kubernetes

# Download and Install Worker Binaries

url=https://storage.googleapis.com/kubernetes-release/release
version=$(curl -s ${url}/stable.txt)

curl -LO ${url}/${version}/bin/linux/amd64/kubectl
curl -LO ${url}/${version}/bin/linux/amd64/kube-proxy
curl -LO ${url}/${version}/bin/linux/amd64/kubelet

url=https://github.com/kubernetes-sigs/cri-tools
version=$(github_latest ${url})
github_download ${url} ${version} crictl-v${version}-linux-amd64.tar.gz
tar -xvf crictl-v${version}-linux-amd64.tar.gz

url=https://github.com/opencontainers/runc
version=$(github_latest ${url})
github_download ${url} ${version} runc.amd64
mv runc.amd64 runc

url=https://github.com/containernetworking/plugins
version=$(github_latest ${url})
github_download ${url} ${version} cni-plugins-linux-amd64-${version}.tgz
tar -xvf cni-plugins-linux-amd64-${version}.tgz -C /opt/cni/bin/

url=https://github.com/containerd/containerd
version=$(github_latest ${url})
github_download ${url} ${version} containerd-${version}.linux-amd64.tar.gz
mkdir containerd
tar -xvf containerd-${version}.linux-amd64.tar.gz -C containerd

# Install the worker binaries

chmod +x crictl kubectl kube-proxy kubelet runc 
sudo mv crictl kubectl kube-proxy kubelet runc /usr/local/bin/
sudo mv containerd/bin/* /bin/

# Create the bridge network configuration file

cat <<EOF | sudo tee /etc/cni/net.d/10-bridge.conf
{
    "cniVersion": "1.0.0",
    "name": "bridge",
    "type": "bridge",
    "bridge": "cnio0",
    "isGateway": true,
    "ipMasq": true,
    "ipam": {
        "type": "host-local",
        "ranges": [
          [{"subnet": "${cluster_network}"}]
        ],
        "routes": [{"dst": "0.0.0.0/0"}]
    }
}
EOF

# Create the loopback network configuration file:

cat <<EOF | sudo tee /etc/cni/net.d/99-loopback.conf
{
    "cniVersion": "1.0.0",
    "name": "lo",
    "type": "loopback"
}
EOF

# Configure containerd

sudo mkdir -p /etc/containerd/

cat << EOF | sudo tee /etc/containerd/config.toml
[plugins]
  [plugins.cri.containerd]
    snapshotter = "overlayfs"
    [plugins.cri.containerd.default_runtime]
      runtime_type = "io.containerd.runtime.v1.linux"
      runtime_engine = "/usr/local/bin/runc"
      runtime_root = ""
EOF

cat <<EOF | sudo tee /etc/systemd/system/containerd.service
[Unit]
Description=containerd container runtime
Documentation=https://containerd.io
After=network.target

[Service]
ExecStartPre=/sbin/modprobe overlay
ExecStart=/bin/containerd
Restart=always
RestartSec=5
Delegate=yes
KillMode=process
OOMScoreAdjust=-999
LimitNOFILE=1048576
LimitNPROC=infinity
LimitCORE=infinity

[Install]
WantedBy=multi-user.target
EOF

# Configure Kubelet

sudo cp worker-0-key.pem worker-0.pem /var/lib/kubelet/
sudo cp worker-0.kubeconfig /var/lib/kubelet/kubeconfig
sudo cp ca.pem /var/lib/kubernetes/

cat <<EOF | sudo tee /var/lib/kubelet/kubelet-config.yaml
kind: KubeletConfiguration
apiVersion: kubelet.config.k8s.io/v1beta1
authentication:
  anonymous:
    enabled: false
  webhook:
    enabled: true
  x509:
    clientCAFile: "/var/lib/kubernetes/ca.pem"
authorization:
  mode: Webhook
clusterDomain: "${cluster_domain}"
clusterDNS:
  - "${cluster_dns}"
podCIDR: "${cluster_network}"
resolvConf: "/run/systemd/resolve/resolv.conf"
runtimeRequestTimeout: "15m"
tlsCertFile: "/var/lib/kubelet/${hostname}.pem"
tlsPrivateKeyFile: "/var/lib/kubelet/${hostname}-key.pem"
EOF

cat <<EOF | sudo tee /etc/systemd/system/kubelet.service
[Unit]
Description=Kubernetes Kubelet
Documentation=https://github.com/kubernetes/kubernetes
After=containerd.service
Requires=containerd.service

[Service]
ExecStart=/usr/local/bin/kubelet \\
  --config=/var/lib/kubelet/kubelet-config.yaml \\
  --container-runtime=remote \\
  --container-runtime-endpoint=unix:///var/run/containerd/containerd.sock \\
  --image-pull-progress-deadline=2m \\
  --kubeconfig=/var/lib/kubelet/kubeconfig \\
  --network-plugin=cni \\
  --register-node=true \\
  --v=2
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

# Configure the Kubernetes Proxy

sudo cp kube-proxy.kubeconfig /var/lib/kube-proxy/kubeconfig

cat <<EOF | sudo tee /var/lib/kube-proxy/kube-proxy-config.yaml
kind: KubeProxyConfiguration
apiVersion: kubeproxy.config.k8s.io/v1alpha1
clientConnection:
  kubeconfig: "/var/lib/kube-proxy/kubeconfig"
mode: "iptables"
clusterCIDR: ${cluster_network}
EOF

cat <<EOF | sudo tee /etc/systemd/system/kube-proxy.service
[Unit]
Description=Kubernetes Kube Proxy
Documentation=https://github.com/kubernetes/kubernetes

[Service]
ExecStart=/usr/local/bin/kube-proxy \\
  --config=/var/lib/kube-proxy/kube-proxy-config.yaml
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

# Start the Worker Services

sudo systemctl daemon-reload
sudo systemctl enable containerd kubelet kube-proxy
sudo systemctl restart containerd kubelet kube-proxy


# Get back to the root directory as the next script will be executed from there and
# _common.sh cd's into the cluster directory
cd -