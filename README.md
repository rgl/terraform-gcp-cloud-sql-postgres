# About

This creates an example GCP Cloud SQL PostgreSQL instance using terraform.

This will:

* Create a public PostgreSQL instance.
* Configure the PostgresSQL instance to require mTLS.
* Enable automated backups.
* Set a random `postgres` account password.
* Show how to connect to the created PostgreSQL instance using `psql`.

## Usage

Install `terraform`, `gcloud`, and `docker`.

Login into your GCP account:

```bash
# see https://cloud.google.com/sdk/docs/authorizing
gcloud auth login --no-launch-browser
gcloud config set project PROJECT_ID # gcloud projects list
gcloud config set compute/region REGION_ID # gcloud compute regions list
gcloud auth application-default login --no-launch-browser
```

Verify your GCP account settings:

```bash
gcloud config get account
gcloud config get project
gcloud config get compute/region
```

Create the example:

```bash
export CHECKPOINT_DISABLE=1
export TF_LOG=TRACE
export TF_LOG_PATH=terraform.log
export TF_VAR_project="$(gcloud config get project)"
export TF_VAR_region="$(gcloud config get compute/region)"
terraform init
terraform plan -out=tfplan
# NB it takes about 20m to create a simple google_sql_database_instance. YMMV.
terraform apply tfplan
```

Connect to it:

```bash
# see https://www.postgresql.org/docs/14/libpq-envars.html
# see https://cloud.google.com/sql/docs/postgres/connect-admin-ip?authuser=2#connect-ssl
terraform output -raw ca >pgcacerts.pem
terraform output -raw crt >postgres-crt.pem
install -m 600 /dev/null postgres-key.pem
terraform output -raw key >postgres-key.pem
install -m 600 /dev/null pgpass.conf
echo "$(terraform output -raw ip_address):5432:postgres:postgres:$(terraform output -raw password)" >pgpass.conf
docker run \
    --rm \
    -it \
    -v "$PWD:/host:ro" \
    -e "PGSSLROOTCERT=/host/pgcacerts.pem" \
    -e "PGSSLCERT=/host/postgres-crt.pem" \
    -e "PGSSLKEY=/host/postgres-key.pem" \
    -e "PGPASSFILE=/host/pgpass.conf" \
    -e "PGHOSTADDR=$(terraform output -raw ip_address)" \
    -e "PGSSLMODE=verify-ca" \
    -e "PGDATABASE=postgres" \
    -e "PGUSER=postgres" \
    postgres:14 \
    psql
```

Execute example queries:

```sql
select version();
select current_user;
select case when ssl then concat('YES (', version, ')') else 'NO' end as ssl from pg_stat_ssl where pid=pg_backend_pid();
```

Exit the `psql` session:

```sql
exit
```

Destroy everything:

```bash
# disable the delete protection.
sed -i -E 's,(deletion_protection).*?=.*,\1 = false,g' main.tf
terraform plan -out=tfplan
terraform apply tfplan
# destroy everything, including all the data.
terraform destroy
# enable the delete protection (only in the source code, as the instance is already gone).
sed -i -E 's,(deletion_protection).*?=.*,\1 = true,g' main.tf
```
