variable "allowed_ips" {
  description = "Lista de direcciones IP permitidas (Variables de ejemplo, estan serian la de los equipos de los integrantes"
  type        = list(string)
  default     = [
    "123.123.123.123/32",
    "456.456.456.456/32",
    "789.789.789.789/32",
    "101.101.101.101/32",
    "102.102.102.102/32"
  ]
}
