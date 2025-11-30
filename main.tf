# Create product between roles and groups, to be further assigned
locals {

  datasets_with_group = {
    for ds in var.datasets : ds.dataset => ds
    if ds.dataset_group != ""
  }

  dataset_roles = toset([
    "roles/bigquery.metadataViewer",
    "roles/bigquery.jobUser",
  ])
  group_x_roles =  [ 
    for pair in setproduct(local.dataset_roles, values(local.datasets_with_group)[*].dataset_group) : {
      role_name = pair[0]
      member_id = can(regex(".*serviceaccount.*", pair[1])) ? "serviceAccount:${pair[1]}" : pair[1]
    }
  ]
}

# Assign basic roles to the groups associated to each dataset, to make sure they can use BigQuery
resource "google_project_iam_member" "groups_basic_roles" {
  for_each = {
    for permission in local.group_x_roles : "${permission.role_name}.${permission.member_id}" => permission
  }
  role    = each.value.role_name
  member  = each.value.member_id
  project = var.project_id
}

# Create the datasets, with only basic data
resource "google_bigquery_dataset" "create_datasets" {
  for_each = { for ds in var.datasets : ds.dataset => ds }
  
  dataset_id    = each.key
  friendly_name = each.key
  description   = each.value.description
  location      = var.region
  labels        = each.value.dataset_labels
}

# Create datasets owner service account
resource "google_service_account" "datasets_owner" {
  account_id   = var.datasets_owner_sa_name
  display_name = var.datasets_owner_sa_display_name
}

# Assign the owner of the datasets
resource "google_bigquery_dataset_access" "add_owners" {
  for_each = { for ds in local.datasets_with_group : ds.dataset => ds }
  dataset_id = each.key
  role       = "OWNER"
  user_by_email = google_service_account.datasets_owner.email
  depends_on  = [google_bigquery_dataset.create_datasets, google_service_account.datasets_owner]
}

# Add the viewer role to the users defined for each dataset
resource "google_bigquery_dataset_access" "add_viewer_role" {
  for_each = { for ds in local.datasets_with_group : ds.dataset => ds }
  dataset_id = each.key
  role       = "READER"
  user_by_email = each.value.dataset_group
  depends_on  = [google_bigquery_dataset.create_datasets]
}

# Add authorized datasets defined for each dataset
resource "google_bigquery_dataset_access" "authorized_datasets" {
  for_each = {
    for pair in flatten([
      for ds in var.datasets : [
        for auth_dataset in ds.authorized_datasets : {
          dataset_id = ds.dataset
          auth_dataset_id = auth_dataset
        }
      ]
    ]) : "${pair.dataset_id}-${pair.auth_dataset_id}" => pair
  }

  dataset_id = each.value.dataset_id
  role       = "READER"
  dataset {
    project_id = var.project_id
    dataset_id = each.value.auth_dataset_id
  }
  
  depends_on = [google_bigquery_dataset.create_datasets]
}