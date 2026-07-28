# Ansible Playbook — MoMoSim

Installs Docker, deploys the MoMoSim container from ECR, and hardens the server.

## Prerequisites
- Ansible installed locally (`pip install ansible`)
- Server provisioned via Terraform (see ../terraform/)
- SSH key at `~/.ssh/momosim`
- AWS CLI configured (or run from a host with an instance role) if deploying
  manually — the app server itself uses its IAM instance role, no credentials
  needed on the box

## Setup
After running `terraform apply`, copy the output into inventory.ini:
```bash
terraform -chdir=../terraform output -raw ansible_inventory_snippet
```

Paste the result into `ansible/inventory.ini` replacing the placeholder.

## Run the playbook
```bash
cd ansible
ansible-playbook -i inventory.ini playbook.yml \
  --extra-vars "image_uri=<ecr_repository_url>:<tag> ecr_repository_url=<ecr_repository_url>"
```
In normal operation this is run automatically by `cd.yml` on every merge to
`main`, with `image_uri`/`ecr_repository_url` filled in from the image the CD
pipeline just pushed. Run it manually only to redeploy the current `:latest`
tag or to re-apply hardening/config without a new image.

## What it does
1. Installs Docker + the AWS CLI on the Ubuntu server
2. Grants team members SSH access (see below)
3. Configures UFW firewall (allows ports 22 and 3000 only)
4. Hardens SSH (disables root login and password auth)
5. Renders `docker-compose.yml` pointing at the given `image_uri`, logs the
   server in to ECR via its IAM instance role, `docker compose pull`s the new
   image, and restarts the service with `docker compose up -d`

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