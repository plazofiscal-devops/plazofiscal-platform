locals {
  governance_prefix = "${var.client}-${var.project}-${var.environment}"
  cluster_name      = "${local.governance_prefix}-aks-main"

  tags = {
    Client      = var.client
    Project     = var.project
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}
