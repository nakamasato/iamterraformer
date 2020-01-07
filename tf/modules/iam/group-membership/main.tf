resource "aws_iam_group_membership" "group-membership" {
  for_each = var.group_memberships
  name     = "${each.key}-group-membership"
  group    = each.key
  users    = each.value
}
