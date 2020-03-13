---
title: "Terraform: Cannot delete entity, must delete policies first"
date: 2020-02-25T10:23:04Z
draft: false 
tags: ["terraform", "aws"]
---

Just one of those day-to-day things that you come across, fix, forget; then come across again and wish you wrote it down.  
Search online and you'll get a bunch of results for getting this error whilst trying to delete an IAM User via terraform `Cannot delete entity, must delete policies first`, the gist is basically you're going to have to go via the CLI.

[Here's the official guide for deleting IAM users](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_manage_delete.html#roles-managingrole-deleting-cli). But obviously thats not why I'm writing this post..

  
  
## Terraform  
Long story short I think this is a bug in terraform. But here is a redacted version of the sort of manifest that I was trying to delete:  
```yaml
resource "aws_iam_user" "problem_service" {
  name = "problem-service-user-name"
  permissions_boundary = "arn:aws:iam::${var.account_id}:policy/my-team"
}

resource "aws_iam_access_key" "problem_service" {
  user = "${aws_iam_user.problem_service.name}"
}

output "problem_service_key_id" {
  value = "${aws_iam_access_key.problem_service.id}"
}

output "problem_service_key_secret" {
  value = "${aws_iam_access_key.problem_service.secret}"
}


data "aws_iam_policy_document" "problem-service" {
  statement {
    actions = [
      "s3:*",
    ]
    resources = [
      "arn:aws:s3:::${var.some_bucket_name}",
      "arn:aws:s3:::${var.some_bucket_name}/*",
    ]
  }
}

resource "aws_iam_user_policy" "problem-service-user-name" {
  name   = "problem-service-user-name"
  user   = "${aws_iam_user.problem_service.name}"
  policy = "${data.aws_iam_policy_document.problem_service.json}"
}
```

Terraform would then complain with:
```sh
Error: Error deleting IAM User problem-service-user-name: DeleteConflict: Cannot delete entity, must delete policies first.
	status code: 409, request id: xxxxxxxxxx
```

Looking online tells you to get the role and delete in via CLI..  
  
  
## No such role!  
In what was probably the most frustrating outcome possible, my first hurdle was what was mean to be the basic step - getting the role name.
```
$ aws iam list-roles | grep problem-service-user-name
$
$ aws iam list-roles | grep problem_service
$
```

Basically nothing worked. I ended up dumping the output to a file to look manually and still nothing. This did though:
```
$ aws iam list-users | grep problem-service-user-name
```

I would give you the output but I've deleted the account and closed that shell (oops). But now I know its a user I can modify the AWS guide a little:  
  

## Solution  
Check you have a user
```sh
$ aws iam list-users | grep problem-service-user-name
```

Find attached policies
```sh
aws iam list-user-policies --user-name problem-service-user-name
```

Delete attached policies _for user_
```sh
$ aws iam delete-user-policy --user-name problem-service-user-name --policy-name problem-service-policy-name
```

Find attached keys
```sh
$ aws iam list-access-keys  --user-name problem-service-user-name
```

Delete attached keys _for user_
```sh
aws iam delete-access-key --access-key-id XXXXXXXXXXXXXXXXXXXX --user-name problem-service-user-name
```

Delete the user
```sh
$ aws iam delete-user --user-name problem-service-user-name
```

