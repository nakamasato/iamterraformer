resource "aws_iam_role_policy_attachment" "attachment" {
  for_each = {
    for pair in var.role_policy_pairs : pair.name => pair
  }
  role       = each.value.role_name
  policy_arn = each.value.policy_arn
}
