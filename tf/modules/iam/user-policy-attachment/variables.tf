variable "user_policy_pairs" {
  description = "list of pairs of user and policy with 'user_name' and 'policy_arns' keys, used for iam_user_policy_attachment"
  type = set(object({
    user_name  = string
    policy_arn = string
    name       = string
  }))
}
