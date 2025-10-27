# output "subnet_cidr_blocks" {
#   value = [for s in data.aws_subnet.eks_clu : s.cidr_block]
# }

output "endpoint" {
  value = aws_eks_cluster.eks_clu.endpoint
  description = "Endpoint for EKS control plane."
}

output "kubeconfig-certificate-authority-data" {
  value = aws_eks_cluster.eks_clu.certificate_authority[0].data
  description = "Base64 encoded certificate data required to communicate with the cluster."
}

output "local-acocunt" {
  value = local.account_id
  description = "AWS account ID"
}