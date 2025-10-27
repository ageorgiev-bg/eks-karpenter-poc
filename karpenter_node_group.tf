resource "aws_eks_node_group" "eks_clu" {
  cluster_name    = var.cluster_name
  version         = var.eks_ver
  node_group_name = "karpenter-nodegroup"
  node_role_arn   = aws_iam_role.karpenter_nodes.arn
  subnet_ids      = [aws_subnet.private_zone1.id, aws_subnet.private_zone2.id]
  capacity_type   = "ON_DEMAND"
  ami_type        = "AL2023_ARM_64_STANDARD"
  instance_types  = var.instance_types
  scaling_config {
    desired_size = 1
    max_size     = 2
    min_size     = 0
  }

  update_config {
    max_unavailable = 1
  }

  labels = {
    role = "general"
  }

  depends_on = [
    aws_subnet.private_zone1, aws_subnet.private_zone2,
    aws_iam_role_policy_attachment.AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.AmazonEKS_CNI_Policy,
    aws_iam_role_policy_attachment.AmazonEC2ContainerRegistryReadOnly
  ]
  # Allows external changes of desired size without impacting Terraform state value
  lifecycle {
    ignore_changes = [scaling_config[0].desired_size]
  }

}



