#!/usr/bin/env sh
set -eu

terraform fmt -check -recursive terraform

for env_dir in terraform/envs/dev terraform/envs/staging terraform/envs/prod; do
  terraform -chdir="$env_dir" init -backend=false -input=false
  terraform -chdir="$env_dir" validate
done
