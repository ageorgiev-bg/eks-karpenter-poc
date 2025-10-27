locals {
  env        = "dev"
  zone1      = "${var.region}a"
  zone2      = "${var.region}b"
  account_id = data.aws_caller_identity.current.account_id

  create_node_sg = true

  cluster_security_group_ingress_rules = {
    ingress_nodes_443 = {
      description = "Node groups to cluster API"
      protocol    = "-1"
      from_port   = 6443
      to_port     = 6443
      type        = "ingress"
      cidr_blocks = "0.0.0.0/0"
    }
  }
  karpenter_nodes_security_group_ingress_rules = {
    ingress_nodes_65535 = {
      description = "Node from the cluster"
      protocol    = "-1"
      from_port   = 1
      to_port     = 65535
      type        = "ingress"
      cidr_blocks = "0.0.0.0/0"
    }
  }

  karpenter_nodes_security_group_egress_rules = {
    nodes_egress_to_cluster = {
      description                  = "Node to the cluster"
      protocol                     = "-1"
      from_port                    = 1
      to_port                      = 65535
      type                         = "egress"
      referenced_security_group_id = aws_eks_cluster.eks_clu.vpc_config[0].cluster_security_group_id
    },
    nodes_egress_net = {
      description = "Node to the net"
      protocol    = "-1"
      from_port   = 1
      to_port     = 65535
      type        = "egress"
      cidr_blocks = "0.0.0.0/0"
    }
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
      rolearn  = aws_iam_role.karpenter_nodes.arn
      username = "system:node:{{EC2PrivateDNSName}}"
      groups   = ["system:bootstrappers", "system:nodes"]
    },
  ]

  tags = { "karpenter.sh/nodepool" = "default",
    "kubernetes.io/cluster/${var.cluster_name}" = "owned",
    "eks:eks-cluster-name"                      = var.cluster_name
  }

}