variable "project_test" {
  description = "Project ID where dataset and table live (company-project)"
  type        = string
}

variable "project_billing" {
  description = "Project ID to bill queries to (partner-project)"
  type        = string
}

variable "region" {
  description = "BigQuery region"
  type        = string
  default     = "europe-west1"
}
