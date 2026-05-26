variable "region" {
  type    = string
  default = "ap-northeast-2"
}

variable "project" {
  type    = string
  default = "msp-monitoring"
}

variable "environment" {
  type    = string
  default = "test"
}

variable "vpc_cidr" {
  type    = string
  default = "10.99.0.0/16"
}

variable "container_image" {
  type    = string
  default = "public.ecr.aws/nginx/nginx:alpine"
}

variable "container_port" {
  type    = number
  default = 80
}

variable "fargate_cpu" {
  type    = number
  default = 256
}

variable "fargate_memory" {
  type    = number
  default = 512
}

variable "desired_count" {
  type    = number
  default = 1
}

variable "use_spot" {
  type    = bool
  default = true
}

variable "health_check_path" {
  type    = string
  default = "/"
}

variable "health_check_matcher" {
  description = "HTTP status code matcher. Change to 201 to force unhealthy."
  type        = string
  default     = "200"
}
