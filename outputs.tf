output "ui" {
  sensitive = false
  value     = "http://${vultr_server.yugabyte_node.0.main_ip}:7000"
}
output "ssh_user" {
  sensitive = false
  value = "${var.ssh_user}"
}
output "ssh_key" {
  sensitive = false
  value     = "${var.ssh_private_key}"
}

output "JDBC" {
  sensitive = false
  value     = "postgresql://yugabyte@${vultr_server.yugabyte_node.0.main_ip}:5433"
}

output "YSQL" {
  sensitive = false
  value     = "ysqlsh -U yugabyte -h ${vultr_server.yugabyte_node.0.main_ip} -p 5433"
}

output "YCQL" {
  sensitive = false
  value     = "ycqlsh ${vultr_server.yugabyte_node.0.main_ip} 9042"
}

output "YEDIS" {
  sensitive = false
  value     = "redis-cli -h ${vultr_server.yugabyte_node.0.main_ip} -p 6379"
}
