variable "group_policy_pairs" {
  description = "list of pairs of group and policy with 'group_name' and 'policy_arns' keys, used for iam_group_policy_attachment"
  type = set(object({
    group_name = string
    policy_arn = string
    name       = string
  }))
}
