schema_version: "1.0"
project:
  id: "cloud-infra-template"
  type: "devops.template.cloud-infra"
  status: "active"
scope:
  owns:
    - "terraform/envs/"
    - "terraform/modules/network/"
    - "terraform/modules/iam/"
    - "terraform/modules/deployment/"
    - "config/backend.hcl.example"
    - "scripts/validate.sh"
  excludes:
    kubernetes_manifests:
      repository: "../k8s-platform-template"
    container_build:
      repository: "../docker-build-template"
    jenkins_pipeline:
      repository: "../jenkins-pipeline-template"
instructions:
  terraform_rules:
    require_remote_state_plan_before_apply: true
    keep_backend_config_out_of_committed_tfvars: true
    require_tags: true
    use_modules_for_reusable_infra: true
    keep_environment_overrides_in_envs: true
  infrastructure_contract:
    modules:
      - "network"
      - "iam"
      - "deployment"
    environments:
      - "dev"
      - "staging"
      - "prod"
  validation:
    required:
      - command: "terraform fmt -check -recursive terraform"
        when: "terraform files change"
      - command: "./scripts/validate.sh"
        when: "terraform CLI is available"
automation:
  enabled: true
  entrypoints:
    validate: "scripts/validate.sh"
    dev: "terraform/envs/dev"
    staging: "terraform/envs/staging"
    prod: "terraform/envs/prod"
