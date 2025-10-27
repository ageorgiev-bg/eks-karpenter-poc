resource "helm_release" "external_nginx" {
  name = "external"

  repository       = "https://kubernetes.github.io/ingress-nginx"
  chart            = "ingress-nginx"
  namespace        = "ingress-nginx"
  create_namespace = true
  version          = "4.13.3"

  values = [file("${path.module}/values/ext-nginx-ing.yaml")]

  # set {
  #   name  = "controller.service.annotations.service\\.beta\\.kubernetes\\.io/aws-load-balancer-ssl-cert"
  #   value = module.acm_backend.acm_certificate_arn
  #   type  = "string"
  # }


  depends_on = [aws_eks_cluster.eks_clu, helm_release.aws_lbc]
}

resource "null_resource" "remove_dangling_sgs" {
  provisioner "local-exec" {
    when    = destroy
    command = <<DOC
        while elb_arn=$(aws elbv2 describe-load-balancers --load-balancer-arns --query 'LoadBalancers[].LoadBalancerArn' --output text); test "$elb_arn" != "";
          do
            aws elbv2 delete-load-balancer --load-balancer-arn $elb_arn
            sleep 10
            aws ec2 delete-security-group --group-id $(aws ec2 describe-security-groups --filters '[{"Name": "tag:elbv2.k8s.aws/resource", "Values": ["*"] }]'  --query "SecurityGroups[0].GroupId" --output text) --query "SecurityGroups[0].GroupId"
          done
    DOC
  }
  depends_on = [helm_release.external_nginx, aws_eks_cluster.eks_clu]
}


