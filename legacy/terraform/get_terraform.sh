#!/bin/bash

set -eoux pipefail

export TF_VERSION="1.14.6"
export OS="linux"
export ARCH="amd64"

# Download the binary
curl -LO "https://releases.hashicorp.com/terraform/${TF_VERSION}/terraform_${TF_VERSION}_${OS}_${ARCH}.zip"

# Download the checksums and the signature
curl -LO "https://releases.hashicorp.com/terraform/${TF_VERSION}/terraform_${TF_VERSION}_SHA256SUMS"
curl -LO "https://releases.hashicorp.com/terraform/${TF_VERSION}/terraform_${TF_VERSION}_SHA256SUMS.sig"

sha256sum --ignore-missing -c terraform_${TF_VERSION}_SHA256SUMS 2>&1 | grep OK

mkdir -p ./gpg_tmp
chmod 700 ./gpg_tmp

# Import HashiCorp's official GPG key
curl -s https://www.hashicorp.com/.well-known/pgp-key.txt | gpg --homedir ./gpg_tmp --import
echo "Curl exit: ${PIPESTATUS[0]:-0}"
echo "GPG exit: ${PIPESTATUS[1]:-0}"

# Verify the signature
gpg --homedir ./gpg_tmp --verify terraform_${TF_VERSION}_SHA256SUMS.sig terraform_${TF_VERSION}_SHA256SUMS

unzip -o terraform_${TF_VERSION}_${OS}_${ARCH}.zip

terraform -version

