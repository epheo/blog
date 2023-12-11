#!/bin/bash

helm repo add coredns https://coredns.github.io/helm
helm --namespace=kube-system install coredns coredns/coredns