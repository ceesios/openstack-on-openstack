terraform {
  required_version = "~> 0.11.7"
}

#Source your rc file to use env variables
provider "openstack" {
  version = "~> 1.14"
}

## COMMON RESOURCES
  # MGMT Net
  resource "openstack_networking_network_v2" "mgmt-net" {
    name              = "${var.clustername}-mgmt-net"
    admin_state_up    = "true"
  }

  resource "openstack_networking_subnet_v2" "mgmt-subnet" {
    name              = "${var.clustername}-mgmt-subnet"
    network_id        = "${openstack_networking_network_v2.mgmt-net.id}"
    cidr              = "${var.mgmt_cidr}"
    dns_nameservers   = ["${var.dns_nameservers}"]
    ip_version        = 4
  }

  resource "openstack_networking_router_v2" "mgmt-router" {
    name              = "${var.clustername}-mgmt-router"
    admin_state_up    = true
    external_network_id = "${var.floating_net_id}"
  }

  resource "openstack_networking_router_interface_v2" "mgmt-router_interface_1" {
    router_id = "${openstack_networking_router_v2.mgmt-router.id}"
    subnet_id = "${openstack_networking_subnet_v2.mgmt-subnet.id}"
  }

  # Priv Net
  resource "openstack_networking_network_v2" "priv-net" {
    name              = "${var.clustername}-priv-net"
    admin_state_up    = "true"
  }

  resource "openstack_networking_subnet_v2" "priv-subnet" {
    name              = "${var.clustername}-priv-subnet"
    network_id        = "${openstack_networking_network_v2.priv-net.id}"
    cidr              = "${var.priv_cidr}"
    ip_version        = 4
  }

  # Pub net
  resource "openstack_networking_network_v2" "pub-net" {
    ## Count should be replaced with conditionals TF in 1.12
    count             = "${var.create_pub_net}"
    name              = "${var.pub_net_name}"
    admin_state_up    = "true"
  }

  resource "openstack_networking_subnet_v2" "pub-subnet" {
    ## Count should be replaced with conditionals TF in 1.12
    count             = "${var.create_pub_net}"
    name              = "${var.clustername}-pub-subnet"
    network_id        = "${openstack_networking_network_v2.pub-net.id}"
    cidr              = "${var.pub_cidr}"
    ip_version        = 4
  }

  data "openstack_networking_network_v2" "pub-net-data" {
    name              = "${var.pub_net_name}"
  }

  data "openstack_networking_secgroup_v2" "secgroup_default" {
    name = "default"
  }

## control HOST
  # FloatingIP
  resource "openstack_networking_floatingip_v2" "floatip_ctrl" {
    pool              = "${var.floating_ip_pool}"
  }

  resource "openstack_compute_instance_v2" "control" {
    name              = "${var.clustername}-control"
    availability_zone = "${element(var.azs, "0")}"
    image_name        = "${var.image_name}"
    flavor_id         = "${var.flavor_id}" 
    key_pair          = "${var.key_pair}"
    security_groups   = ["${var.security_groups}"]
    network {
      name            = "${openstack_networking_network_v2.mgmt-net.name}"
    }
    # network {
    #   name            = "${openstack_networking_network_v2.priv-net.name}"
    # }

    metadata {
      dns_nameservers  = "${var.dns_nameservers}"
      pub_cidr         = "${var.pub_cidr}"
      pub_gw           = "${var.pub_gw}"
    }


    # Provision after associating a floating IP
    connection {
      user            = "ubuntu"
      host            = "${openstack_networking_floatingip_v2.floatip_ctrl.address}"
    }

    # Enter the bastion host into .ssh/config
    provisioner "local-exec" {
      command = <<EOT
        sed -i '/[T]F_BEGIN/,/[T]F_END/d' ~/.ssh/config

        echo '# TF_BEGIN
        Host ${var.clustername}-control ${openstack_networking_floatingip_v2.floatip_ctrl.address}
        StrictHostKeyChecking no
        UserKnownHostsFile=/dev/null
        Hostname ${openstack_networking_floatingip_v2.floatip_ctrl.address}
        User ubuntu

        Host 10.0.0.*
        StrictHostKeyChecking no
        UserKnownHostsFile=/dev/null
        User ubuntu
        ProxyCommand ssh ${var.clustername}-control exec nc %h %p 2>/dev/null
        # TF_END' >> ~/.ssh/config
      EOT
    }

  }

  resource "openstack_compute_floatingip_associate_v2" "fip_control" {
    floating_ip = "${openstack_networking_floatingip_v2.floatip_ctrl.address}"
    instance_id = "${openstack_compute_instance_v2.control.id}"

    connection {
      type            = "ssh"
      user            = "ubuntu"
      host            = "${openstack_networking_floatingip_v2.floatip_ctrl.address}"
    }

    provisioner "remote-exec" {
      inline = [
        "echo terraform executed > /tmp/foo",
        "sleep 10",
        "sudo apt update",
        "sleep 10",
        "sudo apt dist-upgrade -y &"
      ]
    }
  }


## Compute
  # Compute public ports with A.A.P.
  resource "openstack_networking_port_v2" "port_pub" {
    count             = "${var.compute_count}"
    name              = "${var.clustername}-C1${element(var.nodenames, count.index % length(var.nodenames))}-port"
    network_id        = "${data.openstack_networking_network_v2.pub-net-data.id}"
    security_group_ids = ["${data.openstack_networking_secgroup_v2.secgroup_default.id}"]
    admin_state_up    = "true"

    allowed_address_pairs {
      ip_address      = "${var.pub_cidr}"
    }
  }

  # Compute nodes
  resource "openstack_compute_instance_v2" "compute" {
    count             = "${var.compute_count}"
    name              = "${var.clustername}-C1${element(var.nodenames, count.index % length(var.nodenames))}"
    availability_zone = "${element(var.azs, count.index % length(var.azs))}"
    image_name        = "${var.image_name}"
    flavor_id         = "${var.flavor_id}" 
    key_pair          = "${var.key_pair}"
#    user_data         = "${file("common_user_data.sh")}"
    depends_on        = ["openstack_compute_floatingip_associate_v2.fip_control"]
    security_groups   = ["${var.security_groups}"]
    network {
      name            = "${openstack_networking_network_v2.mgmt-net.name}"
    }
    network {
      name            = "${openstack_networking_network_v2.priv-net.name}"
    }
    network {
      name            = "${var.pub_net_name}"
      port            = "${element(openstack_networking_port_v2.port_pub.*.id, count.index)}"
    }

    connection {
      user            = "ubuntu"
      host            = "${openstack_networking_floatingip_v2.floatip_ctrl.address}"
    }

    provisioner "remote-exec" {
      inline = [
        "echo terraform executed > /tmp/foo",
        "sleep 10",
        "sudo apt update",
        "sleep 10",
        "sudo apt dist-upgrade -y &"
      ]
    }
  }
