# Lab lifecycle. Thin wrappers, so that what actually runs stays visible —
# a lab whose commands are opaque teaches the wrapper rather than the tool.

.PHONY: help init plan up inventory ssh-config down fmt validate check

help:
	@echo "make init       download providers"
	@echo "make plan       show what would change"
	@echo "make up         build the lab"
	@echo "make inventory  write inventory.ini and ssh_config from live state"
	@echo "make down       destroy everything, including the bridge"
	@echo "make check      fmt + validate, no credentials needed"

init:
	terraform init

plan:
	terraform plan

up:
	terraform apply
	@$(MAKE) --no-print-directory inventory

# Written after apply rather than during it: the addresses come from the guest
# agent, which needs the machines to have finished booting. If the gateway
# address reads as pending, the agent has not reported yet — wait, then run
# this again.
inventory:
	@terraform output -raw ansible_inventory > inventory.ini
	@terraform output -raw ssh_config > ssh_config
	@echo "wrote inventory.ini and ssh_config"
	@echo "  ssh -F ssh_config lab-idp"
	@echo "  ansible -i inventory.ini lab -m ping"

ssh-config: inventory

# No confirmation prompt beyond Terraform's own. The lab is disposable and
# rebuilding it is the point; anything here worth a second thought does not
# belong in the lab.
down:
	terraform destroy

fmt:
	terraform fmt -recursive

validate:
	terraform validate

# What CI can run without touching a hypervisor.
check:
	terraform fmt -check -recursive
	terraform init -backend=false
	terraform validate
