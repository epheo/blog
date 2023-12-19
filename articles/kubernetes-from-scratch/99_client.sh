
sudo dnf -y install bash-completion

source <(kubectl completion bash)

echo "source <(kubectl completion bash)" >> ~/.bashrc

# Replaces line if it exists, otherwise appends to file
source <(kubectl completion bash | sed s/kubectl/k/g)
echo "source <(kubectl completion bash | sed s/kubectl/k/g)" >> ~/.bashrc

alias k=kubectl
echo "alias k=kubectl" >> ~/.bashrc
