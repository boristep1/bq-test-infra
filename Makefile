# ----- Config -----
PROJECT_TEST = company-project
PROJECT_BILL = partner-project
REGION = europe-west1
CSV = data/products_test.csv

# ----- Terraform targets -----
init:
	terraform init

apply:
	terraform apply -auto-approve \
		-var="project_test=$(PROJECT_TEST)" \
		-var="project_billing=$(PROJECT_BILL)" \
		-var="region=$(REGION)"

# ----- Generate test CSV -----
$(CSV):
	mkdir -p data
	echo "product_id,name,category,price,in_stock,created_at" > $(CSV)
	echo "p1,Red Widget,1,9.99,TRUE,2025-11-01 10:00:00 UTC" >> $(CSV)
	echo "p2,Blue Widget,2,14.50,TRUE,2025-11-02 11:00:00 UTC" >> $(CSV)
	echo "p3,Green Gizmo,1,7.25,FALSE,2025-10-20 09:15:00 UTC" >> $(CSV)
	echo "p4,Yellow Gizmo,2,11.00,TRUE,2025-09-12 14:23:00 UTC" >> $(CSV)
	echo "p5,Purple Thing,3,5.00,TRUE,2025-07-01 08:00:00 UTC" >> $(CSV)

# ----- Load test data into BigQuery -----
load: $(CSV)
	SA1=$$(terraform output -raw user1_email); \
	SA2=$$(terraform output -raw user2_email); \
	bq --location=$(REGION) load --autodetect --source_format=CSV \
		$(PROJECT_TEST):op_test.products $(CSV)

# ----- Create row access policies -----
rls:
	SA1=$$(terraform output -raw user1_email); \
	SA2=$$(terraform output -raw user2_email); \
	bq --location=$(REGION) query --use_legacy_sql=false \
	  "CREATE OR REPLACE ROW ACCESS POLICY products_cat1_policy \
	  ON \`$(PROJECT_TEST).ORp_test.products\` \
	  GRANT TO ('serviceAccount:$${SA1}') \
	  FILTER USING (category = 1);"; \
	bq --location=$(REGION) query --use_legacy_sql=false \
	  "CREATE OR REPLACE ROW ACCESS POLICY products_cat2_policy \
	  ON \`$(PROJECT_TEST).op_test.products\` \
	  GRANT TO ('serviceAccount:$${SA2}') \
	  FILTER USING (category = 2);"

# ----- Create authorized views -----
views:
	bq --location=$(REGION) query --use_legacy_sql=false \
	  "CREATE OR REPLACE VIEW \`$(PROJECT_TEST).op_test.products_view_cat1\` AS \
	  SELECT * FROM \`$(PROJECT_TEST).op_test.products\` WHERE category = 1;"
	bq --location=$(REGION) query --use_legacy_sql=false \
	  "CREATE OR REPLACE VIEW \`$(PROJECT_TEST).op_test.products_view_cat2\` AS \
	  SELECT * FROM \`$(PROJECT_TEST).op_test.products\` WHERE category = 2;"

# ----- Example queries -----
test-query:
	SA1=$$(terraform output -raw user1_email); \
	SA2=$$(terraform output -raw user2_email); \
	echo "Running as $$SA1 (should see category=1):"; \
	gcloud auth application-default login --impersonate-service-account=$$SA1 --quiet; \
	bq --project_id=$(PROJECT_BILL) --location=$(REGION) query --use_legacy_sql=false \
	  "SELECT product_id,category FROM \`$(PROJECT_TEST).op_test.products\` ORDER BY product_id;"; \
	echo "\nRunning as $$SA2 (should see category=2):"; \
	gcloud auth application-default login --impersonate-service-account=$$SA2 --quiet; \
	bq --project_id=$(PROJECT_BILL) --location=$(REGION) query --use_legacy_sql=false \
	  "SELECT product_id,category FROM \`$(PROJECT_TEST).op_test.products\` ORDER BY product_id;"

# ----- Inspect billing proof -----
jobs:
	bq --location=$(REGION) query --use_legacy_sql=false \
	  "SELECT creation_time, user_email, project_id AS billed_project, total_bytes_billed \
	   FROM \`region-$(REGION)\`.INFORMATION_SCHEMA.JOBS_BY_PROJECT \
	   WHERE creation_time >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 1 HOUR) \
	   ORDER BY creation_time DESC LIMIT 20;"

# ----- Full pipeline -----
all: init apply load rls views test-query
