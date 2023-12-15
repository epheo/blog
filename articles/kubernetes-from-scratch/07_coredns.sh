#!/bin/bash

curl https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 | bash

helm repo add coredns https://coredns.github.io/helm
helm --namespace=kube-system install coredns coredns/coredns