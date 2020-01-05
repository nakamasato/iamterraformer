variable "role_policy_pairs" {
  description = "list of pairs of role and policy with 'role_name' and 'policy_arns' keys, used for iam_role_policy_attachment"
  type = set(object({
    role_name  = string
    policy_arn = string
    name       = string
  }))
}
