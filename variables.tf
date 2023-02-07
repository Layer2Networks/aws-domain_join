variable "project_name" {
  description = "Name of the project."
  type        = string
  default     = "test"
}

variable "environment" {
  description = "Name of the environment."
  type        = string
  default     = "dev"
}

variable "subnet_id" {
  description = "Name of the subnet_id to be used"
  type        = string
  default     = "subnet-012345678901234567"
}

variable "directoryId" {
  description = "Name of the subnet_id to be used"
  type        = string
  default     = "d-123456789"
}
