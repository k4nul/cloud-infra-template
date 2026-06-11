#!/usr/bin/env sh
set -eu

export CHECKPOINT_DISABLE="${CHECKPOINT_DISABLE:-1}"
export TF_IN_AUTOMATION="${TF_IN_AUTOMATION:-1}"
export TF_INPUT="${TF_INPUT:-0}"

terraform fmt -check -recursive terraform

for env_dir in terraform/envs/dev terraform/envs/staging terraform/envs/prod; do
  terraform -chdir="$env_dir" init -backend=false -input=false -no-color
  terraform -chdir="$env_dir" validate -no-color
done
