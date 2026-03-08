terraform {
  required_providers {
    digitalocean = {
      source = "digitalocean/digitalocean"
    }
  }
}

provider "digitalocean" {
  # Terraform automatically looks for the DIGITALOCEAN_TOKEN env var
}

resource "digitalocean_firewall" "fastapi_firewall" {
  name = "fastapi-ssh-only"

  # Apply specifically to the fastapi droplet
  droplet_ids = [digitalocean_droplet.fastapi.id]

  # SSH Access
  inbound_rule {
    protocol         = "tcp"
    port_range       = "22"
    source_addresses = ["0.0.0.0/0", "::/0"]
  }

  # FastAPI Access
  inbound_rule {
    protocol         = "tcp"
    port_range       = "8000"
    source_addresses = ["0.0.0.0/0", "::/0"]
  }

  # Allow all outbound traffic (standard default)
  outbound_rule {
    protocol              = "tcp"
    port_range            = "1-65535"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }

  outbound_rule {
    protocol              = "udp"
    port_range            = "1-65535"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }
}

resource "digitalocean_firewall" "wireguard_firewall" {
  name = "wireguard-ssh-only"

  # Apply specifically to the wireguard droplet
  droplet_ids = [digitalocean_droplet.wireguard.id]

  # SSH Access
  inbound_rule {
    protocol         = "tcp"
    port_range       = "22"
    source_addresses = ["0.0.0.0/0", "::/0"]
  }

  # WireGuard VPN Port
  inbound_rule {
    protocol         = "udp"
    port_range       = "51820"
    source_addresses = ["0.0.0.0/0", "::/0"]
  }

  # Allow all outbound traffic
  outbound_rule {
    protocol              = "tcp"
    port_range            = "1-65535"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }

  outbound_rule {
    protocol              = "udp"
    port_range            = "1-65535"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }
}

variable "ssh_key_path_private" {
  type        = string
  description = "The local path to your private SSH key"
}

variable "ssh_key_path_public" {
  type        = string
  description = "The local path to your public SSH key"
}

resource "digitalocean_ssh_key" "my_key" {
  name       = "assessment"
  public_key = file(var.ssh_key_path_public)
}

# Define the tag
resource "digitalocean_tag" "assessment_tag" {
  name = "assessment"
}

resource "digitalocean_droplet" "wireguard" {
  name     = "almalinux-s-1vcpu-1gb-sfo3-01-wireguard"
  size     = "s-1vcpu-1gb"
  region   = "sfo3"
  image    = "almalinux-9-x64"
  ssh_keys = [digitalocean_ssh_key.my_key.id]

  # Link the tag here
  tags     = [digitalocean_tag.assessment_tag.id]
}

resource "digitalocean_droplet" "fastapi" {
  name     = "almalinux-s-1vcpu-1gb-sfo3-01-fastapi"
  size     = "s-1vcpu-1gb"
  region   = "sfo3"
  image    = "almalinux-9-x64"
  ssh_keys = [digitalocean_ssh_key.my_key.id]

  # Link the tag here
  tags     = [digitalocean_tag.assessment_tag.id]
}

output "wireguard_ip" {
  value = digitalocean_droplet.wireguard.ipv4_address
}

output "fastapi_ip" {
  value = digitalocean_droplet.fastapi.ipv4_address
}

resource "local_file" "ansible_inventory" {
  content  = <<-EOT
    [wireguard]
    ${digitalocean_droplet.wireguard.ipv4_address} ansible_host=${digitalocean_droplet.wireguard.ipv4_address} private_ip=${digitalocean_droplet.wireguard.ipv4_address_private} ansible_user=root ansible_ssh_private_key_file=${var.ssh_key_path_private}

    [fastapi]
    ${digitalocean_droplet.fastapi.ipv4_address} ansible_host=${digitalocean_droplet.fastapi.ipv4_address} private_ip=${digitalocean_droplet.fastapi.ipv4_address_private} ansible_user=root ansible_ssh_private_key_file=${var.ssh_key_path_private}
  EOT
  filename = "../ansible/hosts.ini"
}
