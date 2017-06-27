#!/bin/bash

# Connects to the cluster # TODO: (put that in a separate script to avoid code duplication)
BASTION_IP="$1"
BASTION_SSH_PORT="$2"
TERRAFORM_KEYFILE="$3"
CLUSTER_NAME="$4"
INTERNAL_DOMAIN="$5"

echo " ((((())))) Waiting for the Kubernetes master cluster to be available..."

echo " ((((())))) Configuring local kubectl to talk to the APIServer..."
set +e
killall ssh
set -e
sleep 2s
ssh -oStrictHostKeyChecking=no -t -t -A -L "6443:k8s.$CLUSTER_NAME.$INTERNAL_DOMAIN:443" -p "$BASTION_SSH_PORT" -i "$TERRAFORM_KEYFILE" terraform@"$BASTION_IP" &
sleep 2s
tlsdir="./tls/${CLUSTER_NAME}"
echo "Configuring Kube Control ! (binding local kubectl to the remote one on AWS)"
kubectl config set-cluster "$CLUSTER_NAME" --server="https://k8s.$CLUSTER_NAME.$INTERNAL_DOMAIN:6443" --certificate-authority="${tlsdir}/ca.pem"
kubectl config set-credentials "$CLUSTER_NAME-default-admin" --certificate-authority="${tlsdir}/ca.pem" --client-key="${tlsdir}/administrator.key" --client-certificate="${tlsdir}/administrator.pem"
kubectl config set-context "$CLUSTER_NAME-default-system" --cluster="$CLUSTER_NAME" --user="$CLUSTER_NAME-default-admin"
kubectl config use-context "$CLUSTER_NAME-default-system"


# Spawns our kubernetes manifests :)
echo "Spawing/updating Kubernetes manifests..."
i=6
while [[ ! -z "${!i}" ]]; do
  echo "${!i}" > manifest.yml
  kubectl apply -f manifest.yml
  i=$((i+1))
done

# Bye
killall ssh