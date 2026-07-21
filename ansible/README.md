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
2. Grants team members SSH access (see below)
3. Configures UFW firewall (allows ports 22 and 3000 only)
4. Hardens SSH (disables root login and password auth)
5. Clones the repo and builds + runs the container

## Adding a teammate's SSH access
Add their public key to `team_ssh_keys` in `group_vars/all.yml`:
```yaml
team_ssh_keys:
  - "ssh-ed25519 AAAA... existing-teammate"
  - "ssh-ed25519 AAAA... new-teammate@host"
```
Re-run the playbook — it appends any new key to the `ubuntu` user's
`authorized_keys` on the server (existing keys are left untouched). No manual
SSH or server login required, and the access list is versioned in the repo
instead of living only on the box.

## Verify deployment
```bash
curl http://YOUR_SERVER_IP:3000
```