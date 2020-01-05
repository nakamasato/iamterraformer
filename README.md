# IAM Resouces

## UML


```plantuml

```

## Module Design

### Reference among modules

- Terraform just allows a parent module to reference its child output ([Output Values](https://www.terraform.io/docs/configuration/outputs.html))
- `policy` and `user` need to be referenced by `user_policy_attachment`
- `policy` and `group` need to be referenced by `group_policy_attachment`
- `policy` and `role` need to be referenced by `role_policy_attachment`
- `group` and `user` need to be referenced by `group_membership`

### Limitation of Terraform

https://github.com/hashicorp/terraform/blob/master/terraform/eval_for_each.go#L23

> The "for_each" value depends on resource attributes that cannot be determined until apply, so Terraform cannot predict how many instances will be created. To work around this, use the -target argument to first apply only the resources that the for_each depends on.



## Import the existing resources into the module

### 1. Import the resources

```
./import_script.sh [-f]
```

1. Import `tf` and `tfstate` for existing resources
    - `terrafroming`: `iamu` (`tags` is not including), `iamp`, `iamg`, `iamgm`
    - `practice_terraforming`: `iamr` (`description` is not included in `terraforming`), `iamgpa`, `iamrpa`, `iamupa` (not implemented in `terraforming`)
1. Replace `${aws:username}` with `$${aws:username}`

1. `terraform init` with local backend and `terraform plan` to check the imported tfstate and tf files are consistent

```
No changes. Infrastructure is up-to-date.
```

### 2. Convert into the resources with designed module

|imported state|destination|
|---|---|---|
|`aws_iam_user.<name>`|`module.dev.user.aws_iam_user.<user_name>`|
|`aws_iam_group.<name>`|`module.dev.module.group.module.<group_name>.aws_iam_group.group`|
|`aws_iam_role.<name>`|`module.dev.module.role.aws_iam_role.<role_name>`|
|`aws_iam_policy.<name>`|`module.dev.module.policy.aws_iam_policy.<policy_name>`|
|`aws_iam_group_membership.<name>`|`module.dev.module.group.module.<group_name>.aws_iam_group_membership.group_membership`|
|`aws_iam_group_policy_attachment`|`module.dev.policy-attachment.aws_iam_group_policy_attachment.attachment["<group_name>-<policy_name>"]`|
|`aws_iam_user_policy_attachment`|`module.dev.policy-attachment.aws_iam_user_policy_attachment.attachment["<user_name>-<policy_name>"]`|
|`aws_iam_role_policy_attachment`|`module.dev.policy-attachment.aws_iam_role_policy_attachment.attachment["<role_name>-<policy_name>"]`|


1. Prepare `main.tf`, `output.tf`, `dev/main.tf`, `dev/output.tf`

1. move policy

    1. move state
    ```
    mv iamp.tf dev/policy
    for r in `terraform state list | grep ^aws_iam_policy`; do terraform state mv $r module.dev.module.policy.$r; done
    rm terraform.tfstate.*
    ```

    1. create `dev/policy/output.tf`

    ```
    content=`terraform state list | grep ^module.dev.module.policy.aws_iam_policy | sed 's/module.dev.module.policy.\(.*\)/    \(\1.name\) = \1,/'`; echo "output\"policies\"{\nvalue = {\n$content\n}\n}" | terraform fmt - > dev/policy/output.tf
    ```

    1. `dev/output.tf`

    ```diff
     output "dev" {
       value = {
         #group  = module.group.groups,
         policy = module.policy.policies,
         #user   = module.user.users,
         #role   = module.role.roles,
       }
     }
    ```

    1. confirm

    ```
    terraform init
    terraform plan
    ...
    No changes. Infrastructure is up-to-date.
    ```

1. move role

    1. move state
    ```
    mv iamr.tf dev/role
    for r in `terraform state list | grep ^aws_iam_role\.`; do terraform state mv $r module.dev.module.role.$r; done
    rm terraform.tfstate.*
    ```

    1. create `dev/role/output.tf`

    ```
    content=`terraform state list | grep '^module\.dev\.module\.role\.aws_iam_role\.' | sed 's/module.dev.module.role.\(.*\)/    \(\1.name\) = \1,/'`; echo "output\"roles\"{\nvalue = {\n$content\n}\n}" | terraform fmt - > dev/role/output.tf
    ```

    1. `dev/output.tf`

    ```diff
     output "dev" {
       value = {
         #group  = module.group.groups,
         policy = module.policy.policies,
         #user   = module.user.users,
    +     role   = module.role.roles,
       }
     }
    ```

    1. add the following to `dev/main.tf`

    ```
    module "role" {
      source = "./role"
    }
    ```

    1. confirm
    ```
    terraform init
    terraform plan
    ...
    No changes. Infrastructure is up-to-date.
    ```

1. move user

    1. move state

    ```
    mv iamu.tf dev/user
    for r in `terraform state list | grep '^aws_iam_user\.'`; do terraform state mv $r module.dev.module.user.$r; done
    rm terraform.tfstate.*
    ```

    1. create `dev/user/output.tf`
    ```
    content=`terraform state list | grep '^module\.dev\.module\.user\.aws_iam_user\.' | sed 's/module.dev.module.user.\(.*\)/    \(\1.name\) = \1,/'`; echo "output\"users\"{\nvalue = {\n$content\n}\n}" | terraform fmt - > dev/user/output.tf
    ```

    1. `dev/output.tf`

    ```diff
     output "dev" {
       value = {
         #group  = module.group.groups,
         policy = module.policy.policies,
    +     user   = module.user.users,
         role   = module.role.roles,
       }
     }
    ```

    1. add the following to `dev/main.tf`

    ```
    module "user" {
      source = "./user"
    }
    ```

    1. confirm
    ```
    terraform init
    terraform plan
    ...
    No changes. Infrastructure is up-to-date.
    users

1. move group

    1. move state

    ```
    rm iamg.tf
    for r in `terraform state list | grep '^aws_iam_group\.'`; do terraform state mv $r module.dev.module.group.$r; done
    rm terraform.tfstate.*
    for g in `terraform state list | grep '\.aws_iam_group\.' | sed 's/.*\.aws_iam_group\.\(.*\)/\1/'`; do terraform state mv module.dev.module.group.aws_iam_group.$g module.dev.module.group.module.$g.aws_iam_group.group; done
    rm terraform.tfstate.*
    ```

    1. create `dev/group/main.tf`

    ```
     tf=dev/group/main.tf; rm -f $tf; for g in `terraform state list | grep 'aws_iam_group\.' | sed 's/.*aws_iam_group\.\(.*\)/\1/'`; do echo "module\"$g\"{\nsource=\"../../../modules/naka/iam/group\"\ngroup_name=\"$g\"\nuser_name_list=var.group_members[\"$g\"]\n}\n" >> $tf; done; terraform fmt $tf
    ```

    1. create `dev/group/output.tf`
    ```
    content=`terraform state list | grep '^module\.dev\.module\.group\.aws_iam_group\.' | sed 's/module.dev.module.group.aws_iam_group.\(.*\)/    "\1" = module.\1.group,/'`; echo "output\"groups\"{\nvalue = {\n$content\n}\n}" | terraform fmt - > dev/group/output.tf
    ```

    1. `dev/output.tf`

    ```diff
     output "dev" {
       value = {
    +     group  = module.group.groups,
         policy = module.policy.policies,
         user   = module.user.users,
         role   = module.role.roles,
       }
     }
    ```

    1. add the following to `dev/main.tf`

    ```
    module "group" {
      source = "./group"
    }
    ```

    1. move group membership

    ```
    for g in `terraform state list | grep '^aws_iam_group_membership\.' | sed 's/aws_iam_group_membership.\(.*\)/\1/'`; do terraform state mv aws_iam_group_membership.$g module.dev.module.group.module.$g.aws_iam_group_membership.group_membership; done
    rm terraform.tfstate.*
    ```

    1. write the membership in `dev/main.tf` <- Very wasteful

    ```
    tf=dev/group_membership.tf; rm -f $tf; echo "module\"group\"{\nsource = \"./group\"\ngroup_members = {" >> $tf; for g in `grep aws_iam_group_membership iamgm.tf | sed 's/.*aws_iam_group_membership" "\(.*\)".*/\1/'`; do user_str=`grep -A 2 -e "aws_iam_group_membership\" \"$g\"" iamgm.tf | grep users | sed -e 's/.*users = \[\([^]]*\)\]/\1/' -e 's/\"//g' -e 's/,//g'`; echo "\"$g\"=[" >>$tf; for u in `echo "$user_str"`; do echo "module.user.users[\"$u\"].name," >> $tf; done; echo "]," >> $tf; done; echo "}\n}" >> $tf; terraform fmt $tf
    ```

    1. `dev/group/variables.tf`

    ```
    variable "group_members" {
      description = "group name to list of users"
      type        = map
    }
    ```

    1. rm `iamgm.tf`

    ```
    rm iamgm.tf
    ```

    1. confirm
    ```
    terraform init
    terraform plan
    ...
    No changes. Infrastructure is up-to-date.
    ```

1. move iamgpa

    1. Create `dev/policy_attachment.tf`

    ```
    ```

## Notice

### Imported resources

- aws_iam_policy (`terraforming`)
- aws_iam_user (`terraforming`)
- aws_iam_role (`practice_terraforming`)
- aws_iam_group (`terraforming`)
- aws_iam_group_membership (`terraforming`)
- aws_iam_user_policy_attachment (`practice_terraforming`)
- aws_iam_role_policy_attachment (`practice_terraforming`)
- aws_iam_group_policy_attachment (`practice_terraforming`)


### Resources not imported

- aws_iam_user_policy
- aws_iam_role_policy
- aws_iam_group_policy

