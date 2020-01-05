output "iam" {
  value = {
    policy = module.policy.policies,
    role = module.role.roles,
    user = module.user.users,
  }
}
