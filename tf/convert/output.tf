output "iam" {
  value = {
    policy = module.policy.policies,
  }
}
