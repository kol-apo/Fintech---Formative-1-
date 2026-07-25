#!/bin/bash
# =============================================================================
# Bastion first-boot script, rendered by Terraform (templatefile).
# Turns the stock Ubuntu bastion into:
#   1. the NAT for the private subnets (replaces a ~$35/month NAT gateway)
#   2. the app's public front door: forwards :${public_http_port} to the
#      app server's port ${app_port} (replaces a ~$20/month load balancer)
# Both jobs are plain iptables — nothing listens on the bastion itself
# except sshd.
# =============================================================================
set -euxo pipefail

# The instance's single NIC (ens5 on t3, eth0 on t2 — detect, don't assume)
IFACE=$(ip -o -4 route show to default | awk '{print $5}')

# --- 1) NAT for the private subnets -----------------------------------------
cat >/etc/sysctl.d/99-ip-forward.conf <<'EOF'
net.ipv4.ip_forward = 1
EOF
sysctl --system

iptables -t nat -A POSTROUTING -o "$IFACE" -s ${vpc_cidr} -j MASQUERADE

# --- 2) Public URL: forward :${public_http_port} to the app server ----------
iptables -t nat -A PREROUTING -i "$IFACE" -p tcp --dport ${public_http_port} \
  -j DNAT --to-destination ${app_private_ip}:${app_port}

# Masquerade the forwarded flow too, so the app sees the BASTION as the
# source. Two reasons: the app's security group admits the bastion's SG (not
# arbitrary internet IPs), and replies then return through the established
# connection instead of depending on routing.
iptables -t nat -A POSTROUTING -d ${app_private_ip} -p tcp --dport ${app_port} \
  -j MASQUERADE

# --- Persist the rules across reboots ----------------------------------------
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y iptables-persistent
netfilter-persistent save
