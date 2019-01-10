#Source your rc file to use env variables
provider "openstack" {
}

## COMMON RESOURCES
  resource "openstack_networking_network_v2" "privnet_1" {
    name              = "${var.clustername}-privnet_1"
    admin_state_up    = "true"
  }

  resource "openstack_networking_subnet_v2" "privsubnet_1" {
    name              = "${var.clustername}-privsubnet_1"
    network_id        = "${openstack_networking_network_v2.privnet_1.id}"
    cidr              = "192.168.123.0/24"
    ip_version        = 4
  }

  resource "openstack_networking_router_v2" "router_1" {
    name              = "${var.clustername}-router"
    admin_state_up    = true
    external_network_id = "${var.floating_ip_network_id}"
  }

  resource "openstack_networking_router_interface_v2" "router_interface_1" {
    router_id = "${openstack_networking_router_v2.router_1.id}"
    subnet_id = "${openstack_networking_subnet_v2.privsubnet_1.id}"
  }

  resource "openstack_compute_secgroup_v2" "secgroup_ssh" {
    name              = "${var.clustername}-secgroup_ssh"
    description       = "${var.clustername} security group"

    rule {
      from_port   = 22
      to_port     = 22
      ip_protocol = "tcp"
      cidr        = "0.0.0.0/0"
    }
  }

  resource "openstack_compute_secgroup_v2" "secgroup_1" {
    name              = "${var.clustername}-secgroup_1"
    description       = "${var.clustername} security group"

    rule {
      from_port   = 22
      to_port     = 22
      ip_protocol = "tcp"
      cidr        = "0.0.0.0/0"
    }
    rule {
      from_port   = 80
      to_port     = 80
      ip_protocol = "tcp"
      cidr        = "0.0.0.0/0"
    }
    rule {
      from_port   = 443
      to_port     = 443
      ip_protocol = "tcp"
      cidr        = "0.0.0.0/0"
    }
  }

  resource "openstack_networking_floatingip_v2" "floatip_bastion" {
    pool              = "${var.floating_ip_pool}"
  }


## BASTION HOST
  resource "openstack_compute_instance_v2" "bastion" {
    name              = "${var.clustername}-${var.bastion_name}"
    availability_zone = "${element(var.azs, "0")}"
    image_id          = "${var.image_id}"
    flavor_id         = "${var.bastion_flavor_id}" 
    key_pair          = "${var.key_pair}"
    user_data         = "${file("common_user_data.sh")}"
    security_groups   = ["${var.default_security_groups}", "${openstack_compute_secgroup_v2.secgroup_ssh.name}"]
    network {
      name            = "${openstack_networking_network_v2.privnet_1.name}"
    }
    
    connection {
      type            = "ssh"
      user            = "root"
      host            = "${openstack_networking_floatingip_v2.floatip_bastion.address}"
    }
    # Enter the bastion host into .ssh/config
    provisioner "local-exec" {
      command =  <<EOT
        echo 'Host ${var.bastion_name} ${openstack_networking_floatingip_v2.floatip_bastion.address}
StrictHostKeyChecking no
UserKnownHostsFile=/dev/null
Hostname ${openstack_networking_floatingip_v2.floatip_bastion.address}
User root

Host 192.168.123.*
StrictHostKeyChecking no
UserKnownHostsFile=/dev/null
User root
ProxyCommand ssh ${var.bastion_name} exec nc %h %p 2>/dev/null' >> ~/.ssh/config
      EOT

    }    
  }

  resource "openstack_compute_floatingip_associate_v2" "fip_bastion" {
    floating_ip = "${openstack_networking_floatingip_v2.floatip_bastion.address}"
    instance_id = "${openstack_compute_instance_v2.bastion.id}"

    # Provision after associating a floating IP
    connection {
      type            = "ssh"
      user            = "root"
      host            = "${openstack_networking_floatingip_v2.floatip_bastion.address}"
    }

    provisioner "remote-exec" {
      inline = [
        "echo terraform executed > /tmp/foo",
      ]
    }
  }


## LOADBALANCERS
  resource "openstack_networking_port_v2" "port_ha_vip" {
    name              = "${var.clustername}-port_ha_vip"
    network_id        = "${openstack_networking_network_v2.privnet_1.id}"
    admin_state_up    = "true"

    fixed_ip {
      "subnet_id"     = "${openstack_networking_subnet_v2.privsubnet_1.id}"
      "ip_address"    = "192.168.123.254"
    }
  }

  resource "openstack_networking_port_v2" "port_lb" {
    count             = "${var.lb_count}"
    name              = "${var.clustername}-lb-${count.index}-port"
    network_id        = "${openstack_networking_network_v2.privnet_1.id}"
    admin_state_up    = "true"
    fixed_ip {
      "subnet_id"     = "${openstack_networking_subnet_v2.privsubnet_1.id}"
    }

    allowed_address_pairs {
      ip_address      = "${openstack_networking_port_v2.port_ha_vip.fixed_ip.0.ip_address}"
    }

    allowed_address_pairs {
      ip_address      = "1.0.0.0/0"
    }
  }

  resource "openstack_networking_floatingip_v2" "floating_ip_1" {
    pool              = "${var.floating_ip_pool}"
  }

  resource "openstack_compute_instance_v2" "lb" {
    count             = "${var.lb_count}"
    name              = "${var.clustername}-lb-${count.index}"
    availability_zone = "${element(var.azs, count.index)}"
    image_id          = "${var.image_id}"
    flavor_id         = "${var.lb_flavor_id}" 
    key_pair          = "${var.key_pair}"
    user_data         = "${file("common_user_data.sh")}"
    security_groups   = ["${var.default_security_groups}", "${openstack_compute_secgroup_v2.secgroup_1.name}"]
    network {
      name            = "${openstack_networking_network_v2.privnet_1.name}"
      port            = "${element(openstack_networking_port_v2.port_lb.*.id, count.index)}"
   }
    
    metadata {
      ha_vip_address  = "${openstack_networking_port_v2.port_ha_vip.fixed_ip.0.ip_address}"
      ha_floatingips  = "${openstack_networking_floatingip_v2.floating_ip_1.address}"
      ha_execution    = "1"
    }

    connection {
      type            = "ssh"
      user            = "root"
      bastion_host    = "${openstack_networking_floatingip_v2.floatip_bastion.address}"
    }

    #provisioner "remote-exec" {
    #  inline = [
    #  "#! /bin/sh",
    #  "apt update",
    #  "apt -y upgade",
    #  "apt install python -y",
    #  ]
    #}
    
    #provisioner "local-exec" {
    #  command = "ansible-playbook -i '${element(openstack_networking_port_v2.port_lb.*.all_fixed_ips.0, count.index)},' ../ansible/site.yml"
    #  command = "ansible-playbook ../ansible/site.yml --limit ${element(openstack_networking_port_v2.port_lb.*.all_fixed_ips.0, count.index)}"
    #}
  }


## CACHE SERVERS
  resource "openstack_compute_instance_v2" "cache" {
    count             = "${var.cache_count}"
    name              = "${var.clustername}-cache-${count.index}"
    availability_zone = "${element(var.azs, count.index)}"
    image_id          = "${var.image_id}"
    flavor_id         = "${var.cache_flavor_id}" 
    key_pair          = "${var.key_pair}"
    security_groups   = ["${var.default_security_groups}", "${openstack_compute_secgroup_v2.secgroup_1.name}"]
    network {
      name            = "${openstack_networking_network_v2.privnet_1.name}"
    }

    provisioner "remote-exec" {
      inline = [
      "#! /bin/sh",
      "apt update",
      "apt -y upgade",
      "apt install python -y",
      ]
    }
    
    #provisioner "local-exec" {
    #  command = "ansible-playbook -i '${element(openstack_compute_instance_v2.cache.*.access_ip_v4, count.index)},' ../ansible/site.yml"
    #}
  }


## APP SERVERS
  resource "openstack_compute_instance_v2" "app" {
    count             = "${var.app_count}"
    name              = "${var.clustername}-app-${count.index}"
    availability_zone = "${element(var.azs, count.index)}"
    image_id          = "${var.image_id}"
    flavor_id         = "${var.app_flavor_id}" 
    key_pair          = "${var.key_pair}"
    security_groups   = ["${var.default_security_groups}", "${openstack_compute_secgroup_v2.secgroup_1.name}"]
    network {
      name            = "${openstack_networking_network_v2.privnet_1.name}"
    }
  }

## SQL SERVERS
  resource "openstack_compute_instance_v2" "sql" {
    count             = "${var.sql_count}"
    name              = "${var.clustername}-sql_${count.index}"
    availability_zone = "${element(var.azs, count.index)}"
    image_id          = "${var.image_id}"
    flavor_id         = "${var.sql_flavor_id}" 
    key_pair          = "${var.key_pair}"
    security_groups   = ["${var.default_security_groups}", "${openstack_compute_secgroup_v2.secgroup_1.name}"]
    network {
      name            = "${openstack_networking_network_v2.privnet_1.name}"
    }
  }

  resource "openstack_blockstorage_volume_v2" "sql_volume_1" {
    count             = "${var.sql_count}"
    availability_zone = "${element(var.azs, count.index)}"
    name              = "sql_${count.index}_volume_1"
    size              = "${var.sql_volume_size}"
    volume_type       = "${var.sql_volume_type}"
  }

  resource "openstack_compute_volume_attach_v2" "va_sql_1" {
    count             = "${var.sql_count}"
    instance_id       = "${element(openstack_compute_instance_v2.sql.*.id, count.index)}"
    volume_id         = "${element(openstack_blockstorage_volume_v2.sql_volume_1.*.id, count.index)}"
    device            = "/dev/sdb"
  }


## SEARCH SERVERS
  resource "openstack_compute_instance_v2" "ela" {
    count             = "${var.ela_count}"
    name              = "${var.clustername}-ela-${count.index}"
    availability_zone = "${element(var.azs, count.index)}"
    image_id          = "${var.image_id}"
    flavor_id         = "${var.ela_flavor_id}" 
    key_pair          = "${var.key_pair}"
    security_groups   = ["${var.default_security_groups}", "${openstack_compute_secgroup_v2.secgroup_1.name}"]
    network {
      name            = "${openstack_networking_network_v2.privnet_1.name}"
    }
  }

## STORAGE SERVERS
  resource "openstack_compute_instance_v2" "sto" {
    count             = "${var.sto_count}"
    name              = "${var.clustername}-sto-${count.index}"
    availability_zone = "${element(var.azs, count.index)}"
    image_id          = "${var.image_id}"
    flavor_id         = "${var.sto_flavor_id}" 
    key_pair          = "${var.key_pair}"
    security_groups   = ["${var.default_security_groups}", "${openstack_compute_secgroup_v2.secgroup_1.name}"]
    network {
      name            = "${openstack_networking_network_v2.privnet_1.name}"
    }
  }

## REDIS SERVERS
  resource "openstack_compute_instance_v2" "red" {
    count             = "${var.red_count}"
    name              = "${var.clustername}-red-${count.index}"
    availability_zone = "${element(var.azs, count.index)}"
    image_id          = "${var.image_id}"
    flavor_id         = "${var.red_flavor_id}" 
    key_pair          = "${var.key_pair}"
    security_groups   = ["${var.default_security_groups}", "${openstack_compute_secgroup_v2.secgroup_1.name}"]
    network {
      name            = "${openstack_networking_network_v2.privnet_1.name}"
    }
  }

## LOG SERVERS
  resource "openstack_compute_instance_v2" "log" {
    count             = "${var.log_count}"
    name              = "${var.clustername}-log-${count.index}"
    availability_zone = "${element(var.azs, count.index)}"
    image_id          = "${var.image_id}"
    flavor_id         = "${var.log_flavor_id}" 
    key_pair          = "${var.key_pair}"
    security_groups   = ["${var.default_security_groups}", "${openstack_compute_secgroup_v2.secgroup_1.name}"]
    network {
      name            = "${openstack_networking_network_v2.privnet_1.name}"
    }
  }



#output "public_ips" {
#  value = ["${openstack_networking_floatingip_v2.floating_ip_1.fixed_ip}"]
#}