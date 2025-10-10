variable "name" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "cidr_ipv4" {
  type = string
}

variable "subnet_ids" {
  type    = list(string)
  default = []
}

variable "tags" {
  type = map(string)
}
