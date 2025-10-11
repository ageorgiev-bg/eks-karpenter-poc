resource "aws_iam_role" "eks_adm" {
  name = "${local.env}-${var.region}-${var.cluster_name}-admin"

  # Terraform's "jsonencode" function converts a
  # Terraform expression result to valid JSON syntax.
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
      },
    ]
  })

  tags = {
    tag-key = "tag-value"
  }
}

resource "aws_iam_user" "mgr_eks" {
  name = "manager"
}

resource "aws_iam_policy" "eks_adm_pol" {
  name = "AmazonEKSAdminPolicy"

  policy = <<POLICY
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "eks:*"
            ],
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": "iam:PassRole",
            "Resource": "*",
            "Condition": {
                "StringEquals": {
                    "iam:PassedToService": "eks.amazonaws.com"
                }
            }
        }
    ]
}
POLICY
}

resource "aws_iam_role_policy_attachment" "adm_eks" {
  role       = aws_iam_role.eks_adm.name
  policy_arn = aws_iam_policy.eks_adm_pol.arn
}


resource "aws_iam_policy" "assume_adm_eks_pol" {
  name = "AmazonEKSAdminAssumePolicy"

  policy = <<POLICY
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "sts:AssumeRole"
            ],
            "Resource": "${aws_iam_role.eks_adm.arn}"
        }
    ]
}
POLICY
}


resource "aws_iam_user_policy_attachment" "manager" {
  user       = aws_iam_user.mgr_eks.name
  policy_arn = aws_iam_policy.assume_adm_eks_pol.arn
}

resource "aws_eks_access_entry" "manager" {
  cluster_name      = aws_eks_cluster.eks_clu.name
  principal_arn     = aws_iam_role.eks_adm.arn
  kubernetes_groups = ["my-admin"]
}



resource "aws_iam_user" "developer_eks" {
  name = "developer"
}

resource "aws_iam_policy" "developer_eks_policy" {
  name        = "eks_dev_policy"
  path        = "/"
  description = "EKSDevPolicy"


  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "eks:Describe*",
          "eks:List*"
        ]
        Effect   = "Allow"
        Resource = "*"
      },
    ]
  })
}

resource "aws_iam_user_policy_attachment" "developer_eks" {
  user       = aws_iam_user.developer_eks.name
  policy_arn = aws_iam_policy.developer_eks_policy.arn
}

resource "aws_eks_access_entry" "developer_eks_entry" {
  cluster_name      = aws_eks_cluster.eks_clu.id
  principal_arn     = aws_iam_user.developer_eks.arn
  kubernetes_groups = ["my-viewer"]
}