.PHONY: init plan deploy destroy lint pull-tfvars push-tfvars

# deploy reads variables from a tfvars file pulled from Secret Manager.
# Required env vars:
#   BACKEND_BUCKET
#   PROJECT_ID or TF_VAR_project_id
#   ENV_NAME or TF_VAR_environment

BACKEND_PREFIX := deploy-backend

export TF_VAR_backend_bucket := $(BACKEND_BUCKET)
PROJECT_ID ?= $(TF_VAR_project_id)
ENV_NAME ?= $(or $(TF_VAR_environment),$(TF_VAR_env_name))
TFVARS_SECRET_NAME ?= tofu-tfvars-$(ENV_NAME)
TFVARS_FILE ?= ../environments/$(ENV_NAME).tfvars
TFVARS_ARGS := -var-file=$(TFVARS_FILE)

pull-tfvars:
	@test -n "$(PROJECT_ID)" || (echo "ERROR: PROJECT_ID (or TF_VAR_project_id) is required" && exit 1)
	@test -n "$(ENV_NAME)" || (echo "ERROR: ENV_NAME (or TF_VAR_environment) is required" && exit 1)
	@../scripts/tfvars-pull.sh \
		--project="$(PROJECT_ID)" \
		--env="$(ENV_NAME)" \
		--secret="$(TFVARS_SECRET_NAME)" \
		--out="$(TFVARS_FILE)"

push-tfvars:
	@test -n "$(PROJECT_ID)" || (echo "ERROR: PROJECT_ID (or TF_VAR_project_id) is required" && exit 1)
	@test -n "$(ENV_NAME)" || (echo "ERROR: ENV_NAME (or TF_VAR_environment) is required" && exit 1)
	@test -n "$(LOCAL_TFVARS_FILE)" || (echo "ERROR: LOCAL_TFVARS_FILE is required (example: ../environments/devops-care.tfvars)" && exit 1)
	@../scripts/tfvars-push.sh \
		--project="$(PROJECT_ID)" \
		--env="$(ENV_NAME)" \
		--secret="$(TFVARS_SECRET_NAME)" \
		--file="$(LOCAL_TFVARS_FILE)"

init:
	@tofu init \
		-backend-config="bucket=$(BACKEND_BUCKET)" \
		-backend-config="prefix=$(BACKEND_PREFIX)"

plan: pull-tfvars
	@tofu plan -lock=false $(TFVARS_ARGS)

deploy: pull-tfvars
	@tofu apply -auto-approve $(TFVARS_ARGS)

destroy: pull-tfvars
	@tofu destroy $(TFVARS_ARGS)

lint:
	@tofu fmt -write=true -recursive
