resource "aws_iam_group_membership" "group_membership" {
  name  = "${var.group_name}-group-membership"
  users = var.user_name_list
  group = aws_iam_group.group.name
  depends_on = [
    aws_iam_group.group,
  ]
}

resource "aws_iam_group" "group" {
  name = var.group_name
  path = "/"
}
