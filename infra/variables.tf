#variable definitions, both envvars, and local.
variable "REDSHIFT_NAME" {}
variable "REDSHIFT_USER" {}
variable "REDSHIFT_PASSWORD" {}
variable "DB_NAME" {}
variable "DB_RAW_TABLE" {}
variable "REGION" {}
variable "VPC_AZ" {}
variable "PROJECT" {}
variable "S3_BUCKET" {}
variable "KINESIS_FIREHOSE" {}

# local vars in terraform.tfvars are declared down here.