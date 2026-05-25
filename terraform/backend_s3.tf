# Remova ou renomeie este arquivo (ex.: backend_s3.tf.disabled) para usar state local no Learner Lab.
terraform {
  backend "s3" {
    bucket       = "oficina-terraform-state-376854726751-us-east-1"
    key          = "lambda-auth/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}
