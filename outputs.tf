# output "subnet_cidr_blocks" {
#   value = [for s in data.aws_subnet.eks_clu : s.cidr_block]
# }

output "endpoint" {
  value = aws_eks_cluster.eks_clu.endpoint
}

output "kubeconfig-certificate-authority-data" {
  value = aws_eks_cluster.eks_clu.certificate_authority[0].data
}

output "local-acocunt" {
  value = local.account_id
}