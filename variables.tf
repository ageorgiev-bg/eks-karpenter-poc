locals {
  env        = "dev"
  zone1      = "${var.region}a"
  zone2      = "${var.region}b"
  account_id = data.aws_caller_identity.current.account_id

  create_node_sg = true

  cluster_security_group_rules = {
    ingress_nodes_443 = {
      description                = "Node groups to cluster API"
      protocol                   = "-1"
      from_port                  = 6443
      to_port                    = 6443
      type                       = "ingress"
      cidr_blocks                = "0.0.0.0/0"
      ipv6_cidr_blocks           = "::/0"
      source_node_security_group = true
    },
    ingress_nodes_80 = {
      description                = "Node groups to cluster on port 80"
      protocol                   = "-1"
      from_port                  = 80
      to_port                    = 80
      type                       = "ingress"
      cidr_blocks                = "0.0.0.0/0"
      ipv6_cidr_blocks           = "::/0"
      source_node_security_group = true
    },

  }

  aws_auth_configmap_data = {
    mapRoles    = replace(yamlencode(local.aws_auth_roles), "/((?:^|\n)[\\s-]*)\"([\\w-]+)\":/", "$1$2:")
    mapUsers    = replace(yamlencode(local.aws_auth_users), "/((?:^|\n)[\\s-]*)\"([\\w-]+)\":/", "$1$2:")
    mapAccounts = replace(yamlencode(local.aws_auth_accounts), "/((?:^|\n)[\\s-]*)\"([\\w-]+)\":/", "$1$2:")
  }

  aws_auth_users    = []
  aws_auth_accounts = []

  aws_auth_roles = [
    {
      rolearn  = "${aws_iam_role.karpenter_nodes.arn}"
      username = "system:node:{{EC2PrivateDNSName}}"
      groups   = ["system:bootstrappers", "system:nodes"]
    },
  ]

  tags = { "karpenter.sh/nodepool" = "default",
    "kubernetes.io/cluster/${var.cluster_name}" = "owned",
    "eks:eks-cluster-name"                      = var.cluster_name
  }

}


variable "eks_security_group_id" {
  description = "ID of an existing security group to attach to the node groups created"
  type        = string
  default     = ""
}

variable "cluster_security_group_tags" {
  description = "A map of additional tags to add to the cluster security group created"
  type        = map(string)
  default     = {}
}


variable "region" {
  type        = string
  description = "EKS cluster region"
}

variable "cluster_name" {
  type        = string
  description = "Cluster Name"
}

variable "eks_ver" {
  type        = string
  description = "Kubernetes version"
}

variable "instance_types" {
  type        = list(string)
  description = "Instance types"
}
