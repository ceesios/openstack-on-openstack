#Source your rc file to use env variables
provider "openstack" {
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
    cidr              = "${var.mgmt-cidr}"
    ip_version        = 4
  }

  resource "openstack_networking_router_v2" "mgmt-router" {
    name              = "${var.clustername}-mgmt-router"
    admin_state_up    = true
    external_network_id = "${var.floating_ip_network_id}"
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
    cidr              = "${var.priv-cidr}"
    ip_version        = 4
  }

# FloatingIP
  resource "openstack_networking_floatingip_v2" "floatip_ctrl" {
    pool              = "${var.floating_ip_pool}"
  }


## control HOST
  resource "openstack_compute_instance_v2" "control" {
    name              = "${var.clustername}-control"
    availability_zone = "${element(var.azs, "0")}"
    image_name        = "${var.image_name}"
    flavor_id         = "${var.flavor_id}" 
    key_pair          = "${var.key_pair}"
#    user_data         = "${file("common_user_data.sh")}"
    security_groups   = ["${var.default_security_groups}"]
    network {
      name            = "${openstack_networking_network_v2.mgmt-net.name}"
    }
    network {
      name            = "${openstack_networking_network_v2.priv-net.name}"
    }
    # Enter the bastion host into .ssh/config
    provisioner "local-exec" {
      command =  <<EOT
        echo 'Host ${var.clustername}-control ${openstack_networking_floatingip_v2.floatip_ctrl.address}
StrictHostKeyChecking no
UserKnownHostsFile=/dev/null
Hostname ${openstack_networking_floatingip_v2.floatip_ctrl.address}
User ubuntu

Host 10.0.0.*
StrictHostKeyChecking no
UserKnownHostsFile=/dev/null
User ubuntu
ProxyCommand ssh ${var.clustername}-control exec nc %h %p 2>/dev/null' >> ~/.ssh/config
      EOT
    }
  }

  resource "openstack_compute_floatingip_associate_v2" "fip_control" {
    floating_ip = "${openstack_networking_floatingip_v2.floatip_ctrl.address}"
    instance_id = "${openstack_compute_instance_v2.control.id}"

    # Provision after associating a floating IP
    connection {
      type            = "ssh"
      user            = "ubuntu"
      host            = "${openstack_networking_floatingip_v2.floatip_ctrl.address}"
    }

    provisioner "remote-exec" {
      inline = [
        "echo terraform executed > /tmp/foo",
      ]
    }
  }


## Compute
  resource "openstack_compute_instance_v2" "compute" {
    count             = "${var.compute_count}"
    name              = "${var.clustername}-C1${element(var.nodenames, count.index % length(var.nodenames))}"
#    availability_zone = "${element(var.azs, count.index)}"
    availability_zone = "${element(var.azs, count.index % length(var.azs))}"
    image_name        = "${var.image_name}"
    flavor_id         = "${var.flavor_id}" 
    key_pair          = "${var.key_pair}"
#    user_data         = "${file("common_user_data.sh")}"
    security_groups   = ["${var.default_security_groups}"]
    network {
      name            = "${openstack_networking_network_v2.mgmt-net.name}"
    }
    network {
      name            = "${openstack_networking_network_v2.priv-net.name}"
    }
    network {
      name            = "${var.provider-net-name}"
    }

    connection {
      type            = "ssh"
      user            = "ubuntu"
      control_host    = "${openstack_networking_floatingip_v2.floatip_ctrl.address}"
    }

  }
