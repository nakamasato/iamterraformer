# IAM Resouces

## Prerequisite

Terraform 0.12.18
Ruby 2.x

## UML

![sequence dialog](http://www.plantuml.com/plantuml/proxy?src=https://raw.githubusercontent.com/nakamasato/iamterraformer/update-uml-converter/uml/iam_resource_uml.txt)

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

## Usage

1. Import the existing resourcs.

    ```
    ./import.sh
    ```

    it will generate the following files in `imported` directory.

    ```
    tree imported
    imported
    ├── backend.tf
    ├── iam.tfstate
    ├── iamg.tf
    ├── iamgm.tf
    ├── iamgpa.tf
    ├── iamp.tf
    ├── iamr.tf
    ├── iamrpa.tf
    ├── iamu.tf
    ├── iamupa.tf
    ├── plan_result.txt
    └── provider.tf

    0 directories, 12 files
    ```

1. Convert the imported tf resources into the designed module.

    ```
    ./convert.sh
    ```

    it will generate the following files in `converted` directory.

    ```
    tree converted
    converted
    ├── backend.tf
    ├── group
    │   ├── main.tf
    │   ├── output.tf
    │   └── variables.tf
    ├── group_membership.tf
    ├── group_policy_attachment.tf
    ├── iam.tfstate
    ├── main.tf
    ├── output.tf
    ├── policy
    │   ├── main.tf
    │   └── output.tf
    ├── provider.tf
    ├── role
    │   ├── main.tf
    │   └── output.tf
    ├── role_policy_attachment.tf
    ├── user
    │   ├── main.tf
    │   └── output.tf
    └── user_policy_attachment.tf

    4 directories, 18 files
    ```

## Import the existing resources into the module

### 1. Import the resources

```
./import.sh [-f]
```

1. Import `tf` and `tfstate` for existing resources
    - `terrafroming`: `iamp`, `iamg`, `iamgm`
    - `practice_terraforming`: `iamu` (`tags` is not included in `terraforming`), `iamr` (`description` is not included in `terraforming`), `iamgpa`, `iamrpa`, `iamupa` (not implemented in `terraforming`)
1. Replace `${aws:username}` with `$${aws:username}`

1. `terraform init` with local backend and `terraform plan` to check the imported tfstate and tf files are consistent

```
No changes. Infrastructure is up-to-date.
```

### 2. Convert into the resources with designed module

|imported state|destination|
|---|---|
|`aws_iam_user.<name>`|`module.user.aws_iam_user.<user_name>`|
|`aws_iam_group.<name>`|`module.group.module.<group_name>.aws_iam_group.group`|
|`aws_iam_role.<name>`|`module.role.aws_iam_role.<role_name>`|
|`aws_iam_policy.<name>`|`module.policy.aws_iam_policy.<policy_name>`|
|`aws_iam_group_membership.<name>`|`module.group.module.<group_name>.aws_iam_group_membership.group_membership`|
|`aws_iam_group_policy_attachment`|`module.group-policy-attachment.aws_iam_group_policy_attachment.attachment["<group_name>-<policy_name>"]`|
|`aws_iam_user_policy_attachment`|`module.user-policy-attachment.aws_iam_user_policy_attachment.attachment["<user_name>-<policy_name>"]`|
|`aws_iam_role_policy_attachment`|`module.role-policy-attachment.aws_iam_role_policy_attachment.attachment["<role_name>-<policy_name>"]`|


1. Prepare `main.tf`, `output.tf`

1. move policy

    1. `main.tf`

        ```
        module "policy" {
          source = "./policy"
        }
        ```

    1. move state

        ```
        mv iamp.tf policy
        for r in `terraform state list | grep '^aws_iam_policy\.'`; do terraform state mv $r module.policy.$r; done
        rm -f terraform.tfstate.*
        ```

    1. create `policy/output.tf`

        ```
        content=`terraform state list | grep '^module\.policy\.aws_iam_policy\.' | sed 's/module.policy.\(.*\)/    \(\1.name\) = \1,/'`; printf "output\"policies\"{\nvalue = {\n$content\n}\n}" | terraform fmt - > policy/output.tf
        ```

    1. `output.tf`

        ```diff
        output "iam" {
          value = {
            policy = module.policy.policies,
          }
        }
        ```

    1. confirm

        ```
        terraform init
        terraform plan -target=module.policy
        ...
        No changes. Infrastructure is up-to-date.
        ```

1. move role

    1. `main.tf`

        ```diff
        + module "role" {
        +   source = "./role"
        + }
        ```

    1. move state

        ```
        mv iamr.tf role
        for r in `terraform state list | grep ^aws_iam_role\.`; do terraform state mv $r module.role.$r; done
        rm -f terraform.tfstate.*
        ```

    1. create `role/output.tf`

        ```
        content=`terraform state list | grep '^module\.role\.aws_iam_role\.' | sed 's/module.role.\(.*\)/    \(\1.name\) = \1,/'`; printf "output\"roles\"{\nvalue = {\n$content\n}\n}" | terraform fmt - > role/output.tf
        ```

    1. `output.tf`

        ```diff
         output "iam" {
           value = {
             policy = module.policy.policies,
        +    role   = module.role.roles,
           }
         }
        ```

    1. confirm

        ```
        terraform init
        terraform plan -target=module.role
        ...
        No changes. Infrastructure is up-to-date.
        ```

1. move user

    1. `main.tf`

        ```diff
        + module "user" {
        +   source = "./user"
        + }
        ```

    1. move state

        ```
        mv iamu.tf user
        for r in `terraform state list | grep '^aws_iam_user\.'`; do terraform state mv $r module.user.$r; done
        rm terraform.tfstate.*
        ```

    1. create `user/output.tf`

        ```
        content=`terraform state list | grep '^module\.user\.aws_iam_user\.' | sed 's/module.user.\(.*\)/    \(\1.name\) = \1,/'`; printf "output\"users\"{\nvalue = {\n$content\n}\n}" | terraform fmt - > user/output.tf
        ```

    1. `output.tf`

        ```diff
         output "iam" {
           value = {
             policy = module.policy.policies,
             role   = module.role.roles,
        +    user   = module.user.users,
           }
         }
        ```

    1. confirm

        ```
        terraform init
        terraform plan -target=module.user
        ...
        No changes. Infrastructure is up-to-date.
        ```

1. move group

    1. move state

        ```
        rm iamg.tf
        for g in `terraform state list | grep '^aws_iam_group\.' | sed 's/aws_iam_group\.\(.*\)/\1/'`; do terraform state mv aws_iam_group.$g module.group.module.$g.aws_iam_group.group; done
        rm -f terraform.tfstate.*
        ```

    1. create `group/main.tf`

        ```
        GROUP_MODULE_PATH=../../tf/modules/iam/group
        tf=group/main.tf; rm -f $tf; for g in `terraform state list | grep 'aws_iam_group\.' | sed 's/.*aws_iam_group\.\(.*\)/\1/'`; do printf "module\"$g\"{\nsource=\"$GROUP_MODULE_PATH\"\ngroup_name=\"$g\"\nuser_name_list=var.group_members[\"$g\"]\n}\n" >> $tf; done; terraform fmt $tf
        ```

    1. create `group/output.tf`

        ```
        content=`terraform state list | grep '^module\.group\.aws_iam_group\.' | sed 's/module.group.aws_iam_group.\(.*\)/    "\1" = module.\1.group,/'`; printf "output\"groups\"{\nvalue = {\n$content\n}\n}" | terraform fmt - > group/output.tf
        ```

    1. `output.tf`

        ```diff
         output "iam" {
           value = {
             policy = module.policy.policies,
             user   = module.user.users,
             role   = module.role.roles,
        +    group  = module.group.groups,
           }
         }
        ```

    1. move group membership

        ```
        for g in `terraform state list | grep '^aws_iam_group_membership\.' | sed 's/aws_iam_group_membership.\(.*\)/\1/'`; do terraform state mv aws_iam_group_membership.$g module.group.module.$g.aws_iam_group_membership.group_membership; done
        rm terraform.tfstate.*
        ```

    1. write the membership in `main.tf` <- Very wasteful

        ```
        tf=group_membership.tf; rm -f $tf; printf "module\"group\"{\nsource = \"./group\"\ngroup_members = {" >> $tf; for g in `grep aws_iam_group_membership iamgm.tf | sed 's/.*aws_iam_group_membership" "\(.*\)".*/\1/'`; do user_str=`grep -A 2 -e "aws_iam_group_membership\" \"$g\"" iamgm.tf | grep users | sed -e 's/.*users = \[\([^]]*\)\]/\1/' -e 's/\"//g' -e 's/,//g'`; printf "\"$g\"=[" >>$tf; for u in `printf "$user_str"`; do printf "module.user.users[\"$u\"].name," >> $tf; done; printf "]," >> $tf; done; printf "}\n}" >> $tf; terraform fmt $tf
        ```

    1. `group/variables.tf`

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

    1. Move state from `iam_group_policy_attachment` to `module.group-policy-attachment.aws_iam_group_policy_attachment.attachment["<group_name>-<policy_name>"]`
    1. Create `group_policy_attachment.tf`
    1. Remove `iamgpa.tf`

1. move iamrpa

    1. Move state from `iam_role_policy_attachment` to `module.role-policy-attachment.aws_iam_role_policy_attachment.attachment["<role_name>-<policy_name>"]`
    1. Craete `role_policy_attachment.tf`
    1. Remove `iamrpa.tf`

1. move iamupa

    1. Move state from `iam_user_policy_attachment` to `module.user-policy-attachment.aws_iam_user_policy_attachment.attachment["<user_name>-<policy_name>"]`
    1. Craete `user_policy_attachment.tf`
    1. Remove `iamupa.tf`

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
