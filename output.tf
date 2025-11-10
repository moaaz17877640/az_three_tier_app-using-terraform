output "WEB_public_ip" {
  value = azurerm_public_ip.WEB_IP.ip_address
  description = "Public IP for the WEB VM"
}
output "APP_public_ip" {
  value = azurerm_public_ip.app_ip.ip_address
  description = "Public IP for the APP VM"
}
