
data "vultr_os" "yugabyte_db_image" {
    filter {
        name   = "name"
        values = ["CentOS 7 x64"]
    }
}

data "vultr_region" "region_fra" {
    filter {
        name   = "name"
        values = ["Frankfurt"]
    }
}

data "vultr_region" "region_ams" {
    filter {
        name   = "name"
        values = ["Amsterdam"]
    }
}

data "vultr_region" "region_par" {
    filter {
        name   = "name"
        values = ["Paris"]
    }
}

data "vultr_plan" "node_type" {
    filter {
        name   = "name"
        values = ["${var.node_type}"]
    }
}

resource "vultr_ssh_key" "ssh" {
    name = "YugabyteDB SSH"
    ssh_key = trimspace(file("${var.ssh_public_key}"))
}

resource "vultr_server" "yugabyte_node" {
    count = var.node_count
    label = "${var.prefix}${var.cluster_name}-n${format("%d", count.index + 1)}"
    plan_id = data.vultr_plan.node_type.id
    region_id = "${count.index == 0 ? data.vultr_region.region_fra.id : count.index == 1 ? data.vultr_region.region_ams.id : data.vultr_region.region_par.id}"
    tag = "${var.prefix}${var.cluster_name}"

    os_id = data.vultr_os.yugabyte_db_image.id
	
    ssh_key_ids = [vultr_ssh_key.ssh.id]

    provisioner "remote-exec" {
        inline = [
            "mkdir /home/root",
        ]
        connection {
            host = self.main_ip
            type = "ssh"
            user = var.ssh_user
            private_key = file(var.ssh_private_key)
        }
    }
    
    provisioner "file" {
        source = "${path.module}/utilities/scripts/configure_server.sh"
        destination = "/home/${var.ssh_user}/configure_server.sh"
        connection {
            host = self.main_ip
            type = "ssh"
            user = var.ssh_user
            private_key = file(var.ssh_private_key)
        }
    }

    provisioner "file" {
        source = "${path.module}/utilities/scripts/install_software.sh"
        destination = "/home/${var.ssh_user}/install_software.sh"
        connection {
            host = self.main_ip
            type = "ssh"
            user = var.ssh_user
            private_key = file(var.ssh_private_key)
        }
    }

    provisioner "file" {
        source = "${path.module}/utilities/scripts/create_universe.sh"
        destination ="/home/${var.ssh_user}/create_universe.sh"
        connection {
            host = self.main_ip
            type = "ssh"
            user = var.ssh_user
            private_key = file(var.ssh_private_key)
        }
    }
    provisioner "file" {
        source = "${path.module}/utilities/scripts/start_master.sh"
        destination ="/home/${var.ssh_user}/start_master.sh"
        connection {
            host = self.main_ip
            type = "ssh"
            user = var.ssh_user
            private_key = file(var.ssh_private_key)
        }
    }
    provisioner "file" {
        source = "${path.module}/utilities/scripts/start_tserver.sh"
        destination ="/home/${var.ssh_user}/start_tserver.sh"
        connection {
            host = self.main_ip
            type = "ssh"
            user = var.ssh_user
            private_key = file(var.ssh_private_key)
        }
    }
    provisioner "remote-exec" {
        inline = [
            "chmod +x /home/${var.ssh_user}/configure_server.sh",
            "chmod +x /home/${var.ssh_user}/install_software.sh",
            "chmod +x /home/${var.ssh_user}/create_universe.sh",
            "chmod +x /home/${var.ssh_user}/start_tserver.sh",
            "chmod +x /home/${var.ssh_user}/start_master.sh",
            "/home/${var.ssh_user}/install_software.sh '${var.yb_version}'"
        ]
        connection {
            host = self.main_ip
            type = "ssh"
            user = var.ssh_user
            private_key = file(var.ssh_private_key)
        }
    }
}

locals {
    depends_on = ["vultr_server.yugabyte_node"]
    ssh_ip_list = "${var.use_public_ip_for_ssh == "true" ? join(" ",vultr_server.yugabyte_node.*.main_ip) : join(" ",vultr_server.yugabyte_node.*.internal_ip)}"
    config_ip_list = "${join(" ",vultr_server.yugabyte_node.*.main_ip)}"
    zone = "${join(" ", vultr_server.yugabyte_node.*.location)}"
}

resource "null_resource" "create_yugabyte_universe" {
  # Define the trigger condition to run the provisioner block
  triggers = {
    cluster_instance_ids = "${join(",", vultr_server.yugabyte_node.*.id)}"
  }

  depends_on = [vultr_server.yugabyte_node]

  provisioner "local-exec" {
      command = "${path.module}/utilities/scripts/configure_server.sh '${local.ssh_ip_list}' '${var.ssh_user}' ${var.ssh_private_key}"
  }

  provisioner "local-exec" {
      command = "${path.module}/utilities/scripts/create_universe.sh 'Vultr' '${var.region_name}' ${var.replication_factor} '${local.config_ip_list}' '${local.ssh_ip_list}' '${local.zone}' '${var.ssh_user}' ${var.ssh_private_key}"
  }
}

