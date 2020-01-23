# IAM Resouces

## Prerequisite

- Terraform 0.12.18
- Ruby 2.x
- coreutils

## UML

![sequence dialog](http://www.plantuml.com/plantuml/proxy?cache=no&src=https://raw.githubusercontent.com/nakamasato/iamterraformer/master/uml/iam.txt)

## Module Design

### **Entity Modules**

- `user`
- `group`
- `role`
- `policy`

### **Relationship Modules**

- Terraform just allows a parent module to reference its child output ([Output Values](https://www.terraform.io/docs/configuration/outputs.html))

- `user_policy_attachment` (referencing `user` and `policy`)
- `group_policy_attachment` (referencing `group` and `policy`)
- `role_policy_attachment` (referencing `role` and `policy`)
- `group_membership` (referencing `group` and `user`)

### Limitation of Terraform

https://github.com/hashicorp/terraform/blob/master/terraform/eval_for_each.go#L23

> The "for_each" value depends on resource attributes that cannot be determined until apply, so Terraform cannot predict how many instances will be created. To work around this, use the -target argument to first apply only the resources that the for_each depends on.

## Usage

1. Import the existing resourcs.

    ```bash
    ./import.sh [-f]
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

    ```bash
    ./convert.sh [-f]
    ```

    it will generate the following files in `converted` directory.

    ```
    converted
    ├── backend.tf
    ├── group
    │   ├── main.tf
    │   └── output.tf
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

    4 directories, 17 files
    ```

1. Move to your Terraform directory.

    ```
    ./copy_to_your_repo.sh -d /path/to/your/new/iam-dir -m /path/to/module/iam
    ```

    example:

    ```
    ./copy_to_your_repo.sh -d $HOME/terraform/aws/iam -m $HOME/terraform/aws/modules/iam
    ```

## Import the existing resources into the module

### 1. Import the resources

```
./import.sh [-f]
```

1. Import `tf` and `tfstate` for existing resources

    tfstate

    - `iam.tfstate`

    tf with **terraforming**
    - `iamp.tf`
    - `iamg.tf`
    - `iamgm.tf`

    tf with **practice_terraforming**
    - `iamu.tf` (`tags` is not included in `terraforming`)
    - `iamr.tf` (`description` is not included in `terraforming`)
    - `iamgpa.tf` (not implemented in `terraforming`)
    - `iamrpa.tf` (not implemented in `terraforming`)
    - `iamupa.tf` (not implemented in `terraforming`)
1. Replace `${aws:username}` with `$${aws:username}`

1. `terraform init` with local backend and `terraform plan` to check the imported tfstate and tf files are consistent


### 2. Convert into the resources with designed module

|imported state|destination|
|---|---|
|`aws_iam_user.<name>`|`module.user.aws_iam_user.<user_name>`|
|`aws_iam_group.<name>`|`module.group.aws_iam_group.<group_name>`|
|`aws_iam_role.<name>`|`module.role.aws_iam_role.<role_name>`|
|`aws_iam_policy.<name>`|`module.policy.aws_iam_policy.<policy_name>`|
|`aws_iam_group_membership.<name>`|`module.group-membership.aws_iam_group_membership.group-membership["<group_name>"]`|
|`aws_iam_group_policy_attachment`|`module.group-policy-attachment.aws_iam_group_policy_attachment.attachment["<group_name>-<policy_name>"]`|
|`aws_iam_user_policy_attachment`|`module.user-policy-attachment.aws_iam_user_policy_attachment.attachment["<user_name>-<policy_name>"]`|
|`aws_iam_role_policy_attachment`|`module.role-policy-attachment.aws_iam_role_policy_attachment.attachment["<role_name>-<policy_name>"]`|


1. Prepare `main.tf`, `output.tf` and modules

1. move policy

    1. add `policy` module to `main.tf`
    1. move state from `aws_iam_policy` to `module.policy.aws_iam_policy`
    1. create `policy/output.tf` (map of `name` to `aws_iam_policy`)
    1. add `policy = module.policy.policies` to `output.tf`
    1. confirm `terraform plan -target=module.policy`

1. move role

    1. add `role` module to `main.tf`
    1. move state from `aws_iam_role` to `module.role.aws_iam_role`
    1. create `role/output.tf` (map of `name` to `aws_iam_role`)
    1. add `role   = module.role.roles` to `output.tf`
    1. confirm `terraform plan -target=module.role`

1. move user

    1. add `user` module to `main.tf`
    1. move state from `aws_iam_user` to `module.user.aws_iam_user`
    1. create `user/output.tf` (map of `name` to `aws_iam_user`)
    1. add `user   = module.user.users` to `output.tf`
    1. confirm `terraform plan -target=module.user`

1. move group

    1. add `group` module to `main.tf`
    1. move state from `aws_iam_group` to `module.group.aws_iam_group`
    1. create `group/output.tf` (map of `name` to `aws_iam_group`)
    1. add `group   = module.group.groups` to `output.tf`
    1. confirm `terraform plan -target=module.group`



1. move group membership

    1. move state from `iam_group_membership` to `module.group-membership.aws_iam_group_membership.group-membership["<group_name>"]`
    1. convert `iamgm.tf` into `group_membership.tf`

1. move iamgpa

    1. move state from `iam_group_policy_attachment` to `module.group-policy-attachment.aws_iam_group_policy_attachment.attachment["<group_name>-<policy_name>"]`
    1. convert `iamgm.tf` into `group_membership.tf`

1. move iamrpa

    1. move state from `iam_role_policy_attachment` to `module.role-policy-attachment.aws_iam_role_policy_attachment.attachment["<role_name>-<policy_name>"]`
    1. convert `iamgm.tf` into `group_membership.tf`

1. move iamupa

    1. move state from `iam_user_policy_attachment` to `module.user-policy-attachment.aws_iam_user_policy_attachment.attachment["<user_name>-<policy_name>"]`
    1. convert `iamupa.tf` into `user_policy_attachment.tf`

## Imported resources

- [ ] aws_iam_access_key
- [ ] aws_iam_account_alias
- [ ] aws_iam_account_password_policy
- [x] aws_iam_group
- [x] aws_iam_group_membership
- [ ] aws_iam_group_policy
- [x] aws_iam_group_policy_attachment
- [ ] aws_iam_instance_profile
- [ ] aws_iam_openid_connect_provider
- [x] aws_iam_policy
- [ ] aws_iam_policy_attachment
- [ ] aws_iam_role
- [ ] aws_iam_role_policy
- [x] aws_iam_role_policy_attachment
- [ ] aws_iam_saml_provider
- [ ] aws_iam_server_certificate
- [ ] aws_iam_service_linked_role
- [x] aws_iam_user
- [ ] aws_iam_user_group_membership
- [ ] aws_iam_user_login_profile
- [x] aws_iam_user_policy
- [x] aws_iam_user_policy_attachment
- [ ] aws_iam_user_ssh_key
