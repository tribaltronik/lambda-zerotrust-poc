variable "table_name" {
  type        = string
  description = "DynamoDB table name"
}

variable "hash_key" {
  type        = string
  default     = "PK"
  description = "Partition key attribute name"
}

variable "hash_key_type" {
  type        = string
  default     = "S"
  description = "Partition key type (S, N, B)"
}

variable "sort_key" {
  type        = string
  default     = null
  description = "Sort key attribute name (optional)"
}

variable "sort_key_type" {
  type        = string
  default     = "S"
  description = "Sort key type (S, N, B)"
}

variable "enable_ttl" {
  type        = bool
  default     = true
  description = "Enable TTL attribute"
}

variable "ttl_attribute" {
  type        = string
  default     = "expires_at"
  description = "TTL attribute name"
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "Resource tags"
}
