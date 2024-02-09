
Download butane

https://github.com/coreos/butane/releases

sudo mv butane-x86_64-unknown-linux-gnu /usr/bin/butane
chmod +x /usr/bin/butane

butane kernel.bu -o ../kernel.yaml
butane -d . vfio-prepare.bu -o ../vfio-prepare.yaml
