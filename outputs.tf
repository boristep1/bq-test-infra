output "user1_email" {
  value = google_service_account.user1.email
}

output "user2_email" {
  value = google_service_account.user2.email
}

output "dataset_id" {
  value = google_bigquery_dataset.op_test.dataset_id
}

output "table_id" {
  value = google_bigquery_table.products.table_id
}
