resource "aws_iam_user_policy_attachment" "attachment" {
  for_each = {
    for pair in var.user_policy_pairs : pair.name => pair
  }
  user       = each.value.user_name
  policy_arn = each.value.policy_arn
}
