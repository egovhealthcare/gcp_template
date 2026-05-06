.PHONY: init plan deploy destroy lint

# Config is fetched from GCP Secret Manager via data source at plan/apply time.
# Requires: TF_VAR_project_id, TF_VAR_region, TF_VAR_env_name, BACKEND_BUCKET env vars.

BACKEND_PREFIX := infra

export TF_VAR_backend_bucket := $(BACKEND_BUCKET)

init:
	ln -sf ../variables.tf variables.tf
	ln -sf ../config.tf config.tf
	@tofu init \
		-backend-config="bucket=$(BACKEND_BUCKET)" \
		-backend-config="prefix=$(BACKEND_PREFIX)"

plan:
	@tofu plan -lock=false

deploy:
	@tofu apply -auto-approve

destroy:
	@tofu destroy

lint:
	@tofu fmt -write=true -recursive
