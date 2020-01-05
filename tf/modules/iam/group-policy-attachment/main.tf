resource "aws_iam_group_policy_attachment" "attachment" {
  for_each = {
    for pair in var.group_policy_pairs : pair.name => pair
  }
  group      = each.value.group_name
  policy_arn = each.value.policy_arn
}
