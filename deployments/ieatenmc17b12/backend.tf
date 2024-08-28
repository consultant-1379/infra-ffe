terraform {
  backend "pg" {
    conn_str    = "postgres://terraform@infra-awx-backup.athtem.eei.ericsson.se/terraform_backend"
    schema_name = "ieatenmc17b12"
  }
}