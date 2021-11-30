variable "vpc_cidr" {
  default = "10.0.0.0/16"
}

variable "name" {
  default = "My-Test-"
}

variable "public_subnet_cidrs" {
  default = [
    "10.0.11.0/24",
    "10.0.12.0/24",
  ]
}

variable "private_subnet_cidrs" {
  default = [
    "10.0.21.0/24",
    "10.0.22.0/24",
  ]
}

variable "DB_subnet_cidrs" {
  default = [
    "10.0.31.0/24",
    "10.0.32.0/24",
  ]
}
