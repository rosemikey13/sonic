variable "azure_subscription_id" {}

variable "location" {
  default = "East US 2"
}

variable "vn_cidr_block" {
  default = "10.0.0.0/16"
}

variable "artifactory_subnet_cidr_block" {
  default = "10.0.1.0/24"
}

variable "artifactory_db_subnet_cidr_block" {
  default = "10.0.2.0/24"
}

variable "linux_admin" {
  default = "neptune-admin"
  sensitive = true
}

variable "psql_admin" {
  default = "neptune"
}

variable "psql_password" {}


variable "project_path" {
  default = "~/Desktop/neptune"
}

variable "my_ip" {
  default = ""
}