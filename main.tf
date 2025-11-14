terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

provider "google" {
  project = var.project_test
  region  = var.region
}

# ---------- Random IDs for SA names ----------
resource "random_id" "user1" { byte_length = 2 }
resource "random_id" "user2" { byte_length = 2 }

# ---------- Service accounts ----------
resource "google_service_account" "user1" {
  account_id   = "bq-user1-${random_id.user1.hex}"
  display_name = "BigQuery test user 1"
}

resource "google_service_account" "user2" {
  account_id   = "bq-user2-${random_id.user2.hex}"
  display_name = "BigQuery test user 2"
}

# ---------- Dataset ----------
resource "google_bigquery_dataset" "op_test" {
  dataset_id = "op_test"
  project    = var.project_test
  location   = var.region
}

# ---------- IAM grants ----------
# roles/bigquery.dataViewer on company-project
resource "google_project_iam_member" "dv_user1" {
  project = var.project_test
  role    = "roles/bigquery.dataViewer"
  member  = "serviceAccount:${google_service_account.user1.email}"
}

resource "google_project_iam_member" "dv_user2" {
  project = var.project_test
  role    = "roles/bigquery.dataViewer"
  member  = "serviceAccount:${google_service_account.user2.email}"
}

# roles/bigquery.user on partner-project
resource "google_project_iam_member" "bq_user1" {
  project = var.project_billing
  role    = "roles/bigquery.user"
  member  = "serviceAccount:${google_service_account.user1.email}"
}

resource "google_project_iam_member" "bq_user2" {
  project = var.project_billing
  role    = "roles/bigquery.user"
  member  = "serviceAccount:${google_service_account.user2.email}"
}

# ---------- BigQuery table ----------
resource "google_bigquery_table" "products" {
  dataset_id = google_bigquery_dataset.op_test.dataset_id
  table_id   = "products"
  project    = var.project_test

  schema = jsonencode([
    { name = "product_id", type = "STRING", mode = "REQUIRED" },
    { name = "name",       type = "STRING", mode = "NULLABLE" },
    { name = "category",   type = "INTEGER", mode = "NULLABLE" },
    { name = "price",      type = "NUMERIC", mode = "NULLABLE" },
    { name = "in_stock",   type = "BOOL", mode = "NULLABLE" },
    { name = "created_at", type = "TIMESTAMP", mode = "NULLABLE" }
  ])
}
