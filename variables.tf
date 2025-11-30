variable "project_id" {
  type        = string
  description = "GCP project id"
}

variable "region" {
  description = "region"
  type        = string
}

variable "google_credentials" {
  type        = string
  description = "GCP credentials JSON"
  sensitive   = true
}

variable "datasets_owner" {
  description = "Owner of the data warehouse datasets"
  type        = string
}

variable "datasets_owner_sa_name" {
  type        = string
  description = "Service account name for datasets owner"
}

variable "datasets_owner_sa_display_name" {
  type        = string
  description = "Service account display name for datasets owner"
}

variable "datasets" {
  type = list(object({
    dataset             = string
    dataset_group       = string
    description         = string
    authorized_datasets = list(string)
    dataset_labels      = map(string)
  }))
}
