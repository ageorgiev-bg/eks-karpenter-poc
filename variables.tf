variable "eks_clu_security_group_id" {
  description = "ID of an existing security group to attach to the node groups created"
  type        = list(string)
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

variable "create_aws_auth_configmap" {
  type        = bool
  description = "Determines whether to create aws-auth configmap"
  default     = false
}