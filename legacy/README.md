# DigitalOcean Setup and Deployment Instructions

These instructions guide you through the process of obtaining a DigitalOcean API token, deploying DigitalOcean infrastructure using Terraform, and using Ansible to complete Droplet configuration.

## Assumptions to complete the steps
- You have a DigitalOcean account with privileges to create a Droplet.
- You are comfortable with using a Linux terminal (Bash shell).
- Git is available on the terminal.

## DigitalOcean VPC and Droplet Features

- When you create a Droplet in DigitalOcean, it is automatically assigned a Private IP in that VPC.
- The Droplet will automatically be given a Public IP (unless you explicitly opt-out).
- Routing to the internet will work "out of the box."

## DigitalOcean API Token

1. **Log into the DigitalOcean Control Panel.**
2. **Generate an API token:**
   - Click **API** in the left-hand menu.
   - Click **Generate New Token**.
   - Provide a name and ensure both **Read** and **Write** scopes are selected.
   - Copy the token immediately. It will not be shown again.

## Setup on Command Line

### 1. As the root user, create a new user account and switch to that user account

```bash
useradd -m -c 'Test Builder' builder

su - builder
```

### 2. Clone the assessment repository

```bash
git clone https://github.com/listuser/assessment.git
```

### 3. Setup the environment

- Terraform automatically maps environment variables starting with TF_VAR_ to the variables defined in your code.
- Terraform digitalocean provider maps the DIGITALOCEAN_TOKEN from the environment variable.

```bash
export PATH=$PATH:~/assessment/legacy/terraform
export TF_VAR_ssh_key_path_private="~/.ssh/id_ed25519"
export TF_VAR_ssh_key_path_public="~/.ssh/id_ed25519.pub"
export DIGITALOCEAN_TOKEN="CHANGEME_YOUR_TOKEN_HERE"
```

### 4. Generate SSH keys

- Instructions assume you accept the defaults and set a passphrase when prompted.

```bash
ssh-keygen -t ed25519 -C "your_email@example.com"
```

### 5. Download and verify Terraform binary

```bash
cd ~/assessment/legacy/terraform/

bash get_terraform.sh
```

### 6. Initialize the directory, preview the changes, and execute the DigitalOcean deployment

```bash
terraform init

terraform plan

terraform apply
```

### 7. Setup and activate a Python virtual environment then install Ansible

```bash
cd ~/assessment/legacy/ansible/

python3 -m venv venv_ansible

source venv_ansible/bin/activate

pip install --upgrade pip

pip install ansible

export ANSIBLE_HOST_KEY_CHECKING=False
export ANSIBLE_DEPRECATION_WARNINGS=False
```

### 8. Setup ssh-agent

- Start the SSH agent in the background to manage your private keys.

```bash
eval $(ssh-agent -s)

ssh-add ~/.ssh/id_ed25519

ssh-add -l
```

### 9. Run Ansible playbooks

- Verify connectivity and apply the configurations for Wireguard and FastAPI Droplets.

```bash
ansible -i hosts.ini all -m ping

ansible-playbook -i hosts.ini wireguard.yml

ansible-playbook -i hosts.ini fastapi.yml
```

## Testing

### 1. As root user, install and configure Wireguard as a client

```bash
dnf install -y wireguard-tools

cp -v ~builder/assessment/legacy/ansible/wg0-client.conf /etc/wireguard/wg0.conf

chmod -c 600 /etc/wireguard/wg0.conf
chown -c root:root /etc/wireguard/wg0.conf
```

### 2. Bring up VPN and verify connection

```bash
wg-quick up wg0

wg show
ping 10.0.0.1
```

### 3. As non-root user, test FastAPI using pytest

```bash
python3 -m venv venv_test_fastapi

source venv_test_fastapi/bin/activate

pip install --upgrade pip
pip install httpx

python test_fastapi.py
```

## Cleanup

- As root user, down the VPN.

```bash
wg-quick down wg0
```

- As the user, teardown the DigitalOcean infrastructure to avoid ongoing charges on your DigitalOcean account.

```bash
cd ~/assessment/legacy/terraform/

terraform destroy
```
