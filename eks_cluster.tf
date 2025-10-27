# EKS Cluster
resource "aws_eks_cluster" "eks_clu" {
  name    = var.cluster_name
  version = var.eks_ver

  role_arn = aws_iam_role.eks_clu.arn

  vpc_config {
    endpoint_private_access = true
    endpoint_public_access  = true

    subnet_ids = [aws_subnet.private_zone1.id, aws_subnet.private_zone2.id]
  }

  access_config {
    authentication_mode                         = "API_AND_CONFIG_MAP"
    bootstrap_cluster_creator_admin_permissions = true
  }

  tags = merge(local.tags, { "karpenter.sh/discovery" = var.cluster_name })

  depends_on = [
    aws_subnet.private_zone1, aws_subnet.private_zone2, aws_iam_role_policy_attachment.AmazonEKSClusterPolicy
  ]
}

### IAM role for EKS Cluster
## IAM Resources

### EKS CLUSTER role
data "aws_iam_policy_document" "eks_clu" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["eks.amazonaws.com"]
    }

    actions = ["sts:AssumeRole", "sts:TagSession"]
  }
}

resource "aws_iam_role" "eks_clu" {
  name               = "${local.env}-${var.region}-${var.cluster_name}-cluster"
  assume_role_policy = data.aws_iam_policy_document.eks_clu.json
}

resource "aws_iam_role_policy_attachment" "AmazonEKSClusterPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks_clu.name
}

# Optionally, enable Security Groups for Pods
# Reference: https://docs.aws.amazon.com/eks/latest/userguide/security-groups-for-pods.html
resource "aws_iam_role_policy_attachment" "AmazonEKSVPCResourceController" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSVPCResourceController"
  role       = aws_iam_role.eks_clu.name
}



## Security group

resource "aws_security_group" "karpenter_nodes" {

  name        = "${var.cluster_name}-karpenter-nodes"
  description = "Karpenter worker nodes SG"
  vpc_id      = aws_vpc.main.id

  tags = merge(
    local.tags,
    { "Name" = var.cluster_name, "karpenter.sh/discovery" = var.cluster_name }
  )

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group_rule" "ingress_karpenter_nodes" {
  for_each = { for k, v in merge(
    local.karpenter_nodes_security_group_ingress_rules
  ) : k => v if local.create_node_sg }

  # Required
  security_group_id = aws_eks_cluster.eks_clu.vpc_config[0].cluster_security_group_id
  protocol          = each.value.protocol
  from_port         = lookup(each.value, "from_port", null)
  to_port           = lookup(each.value, "to_port", null)
  type              = each.value.type

  source_security_group_id = aws_security_group.karpenter_nodes.id
}

resource "aws_security_group_rule" "ingress_eks_cluster" {
  for_each = { for k, v in merge(
    local.cluster_security_group_ingress_rules
  ) : k => v if local.create_node_sg }

  # Required
  security_group_id = aws_security_group.karpenter_nodes.id
  protocol          = each.value.protocol
  from_port         = lookup(each.value, "from_port", null)
  to_port           = lookup(each.value, "to_port", null)
  type              = each.value.type

  # # Optional
  description = lookup(each.value, "description", null)
  # cidr_blocks              = lookup(each.value, "cidr_blocks", null)
  # ipv6_cidr_blocks         = lookup(each.value, "ipv6_cidr_blocks", null)
  # prefix_list_ids          = lookup(each.value, "prefix_list_ids", null)
  # self                     = lookup(each.value, "self", null)
  source_security_group_id = try(tostring(var.eks_clu_security_group_id), false) ? element(var.eks_clu_security_group_id, 0) : aws_eks_cluster.eks_clu.vpc_config[0].cluster_security_group_id # source_security_group_id = aws_eks_cluster.eks_clu.vpc_config[0].cluster_security_group_id 
}

resource "aws_vpc_security_group_ingress_rule" "karpenter_nodes_ingress" {
  for_each = { for k, v in merge(
    local.karpenter_nodes_security_group_ingress_rules
  ) : k => v if local.create_node_sg }

  # Required
  security_group_id = aws_security_group.karpenter_nodes.id
  ip_protocol       = each.value.protocol
  # from_port         = lookup(each.value, "from_port", null)
  # to_port           = lookup(each.value, "to_port", null)

  # # Optional
  description = lookup(each.value, "description", null)
  # cidr_blocks                  = lookup(each.value, "cidr_blocks", null)
  # ipv6_cidr_blocks             = lookup(each.value, "ipv6_cidr_blocks", null)
  # prefix_list_ids              = lookup(each.value, "prefix_list_ids", null)
  referenced_security_group_id = aws_security_group.karpenter_nodes.id
}

resource "aws_vpc_security_group_egress_rule" "karpenter_nodes_egress" {
  for_each = { for k, v in merge(
    local.karpenter_nodes_security_group_egress_rules
  ) : k => v if local.create_node_sg }

  # Required
  security_group_id = aws_security_group.karpenter_nodes.id
  ip_protocol       = each.value.protocol
  # from_port         = lookup(each.value, "from_port", null)
  # to_port           = lookup(each.value, "to_port", null)

  # # Optional
  description = lookup(each.value, "description", null)
  cidr_ipv4   = lookup(each.value, "cidr_blocks", null)
  # ipv6_cidr_blocks             = lookup(each.value, "ipv6_cidr_blocks", null)
  # prefix_list_ids              = lookup(each.value, "prefix_list_ids", null)
  referenced_security_group_id = lookup(each.value, "referenced_security_group_id", null)
}

# Addons

resource "aws_eks_addon" "kube-proxy" {
  cluster_name                = var.cluster_name
  addon_name                  = "kube-proxy"
  addon_version               = "v1.32.0-eksbuild.2"
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"
}

resource "aws_eks_addon" "coredns" {
  cluster_name                = var.cluster_name
  addon_name                  = "coredns"
  addon_version               = "v1.11.4-eksbuild.2"
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"
}

resource "aws_eks_addon" "vpc_cni" {
  cluster_name                = var.cluster_name
  addon_name                  = "vpc-cni"
  addon_version               = "v1.19.2-eksbuild.5"
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"
  service_account_role_arn    = aws_iam_role.vpc_cni.arn
}

resource "aws_iam_role" "vpc_cni" {
  name               = "vpc-cni-role"
  assume_role_policy = data.aws_iam_policy_document.vpc-cni-policy.json
}

data "aws_iam_policy_document" "vpc-cni-policy" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    principals {
      identifiers = [aws_iam_openid_connect_provider.eks.arn]
      type        = "Federated"
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(aws_iam_openid_connect_provider.eks.url, "https://", "")}:sub"
      values   = ["system:serviceaccount:kube-system:aws-node"]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(aws_iam_openid_connect_provider.eks.url, "https://", "")}:aud"

      values = [
        "sts.amazonaws.com"
      ]
    }


  }
}

resource "aws_iam_role_policy_attachment" "vpc_cni_attach" {
  role       = aws_iam_role.vpc_cni.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}