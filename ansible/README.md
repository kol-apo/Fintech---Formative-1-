# Ansible Playbook — MoMoSim

Installs Docker, deploys the MoMoSim container, and hardens the server.

## Prerequisites
- Ansible installed locally (`pip install ansible`)
- Server provisioned via Terraform (see ../terraform/)
- SSH key at `~/.ssh/momosim`

## Setup
After running `terraform apply`, copy the output into inventory.ini:
```bash
terraform -chdir=../terraform output -raw ansible_inventory_line
```

Paste the result into `ansible/inventory.ini` replacing `YOUR_SERVER_IP`.

## Run the playbook
```bash
cd ansible
ansible-playbook -i inventory.ini playbook.yml
```

## What it does
1. Installs Docker on the Ubuntu server
2. Configures UFW firewall (allows ports 22 and 3000 only)
3. Hardens SSH (disables root login and password auth)
4. Clones the repo and builds + runs the container

## Verify deployment
```bash
curl http://YOUR_SERVER_IP:3000
```