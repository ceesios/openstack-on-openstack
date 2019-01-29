## Define the provider

provider "vsphere" {
  user           = "${var.vsphere_user}"
  password       = "${var.vsphere_pass}"
  vsphere_server = "${var.vsphere_server}"

  # If you have a self-signed cert
  allow_unverified_ssl = true
}

## Gather all resources referenced

data "vsphere_datacenter" "dc" {
  name = "Datacenter"
}

data "vsphere_datastore" "datastore" {
  # name          = "datastore1-esx02"
  name          = "datastoreSSD-esx02"
  datacenter_id = "${data.vsphere_datacenter.dc.id}"
} 

data "vsphere_compute_cluster" "compute_cluster" {
  name          = "cl1"
  datacenter_id = "${data.vsphere_datacenter.dc.id}"
}

# resource "vsphere_resource_pool" "resource_pool" {
#   name                    = "terraform-resource-pool-test"
#   parent_resource_pool_id = "${data.vsphere_compute_cluster.compute_cluster.resource_pool_id}"
# }

data "vsphere_resource_pool" "pool" {
  name          = "cl1/Resources"
  datacenter_id = "${data.vsphere_datacenter.dc.id}"
}

data "vsphere_network" "network" {
  name          = "VM Network"
  datacenter_id = "${data.vsphere_datacenter.dc.id}"
}

data "vsphere_virtual_machine" "template" {
  # name          = "Ubuntu 16.04.2"
  name          = "Ubuntu-16.04-linked-ssd"
  datacenter_id = "${data.vsphere_datacenter.dc.id}"
}

## Create the actual servers
## control
  resource "vsphere_virtual_machine" "control" {
#    count            = "${var.control_count}"
    name             = "${var.clustername}-control${count.index+1}"
    resource_pool_id = "${data.vsphere_compute_cluster.compute_cluster.resource_pool_id}"
    datastore_id     = "${data.vsphere_datastore.datastore.id}"
    folder           = "${var.clustername}/Control"
    num_cpus         = 2
    memory           = 1024
    guest_id         = "${data.vsphere_virtual_machine.template.guest_id}"
    scsi_type        = "${data.vsphere_virtual_machine.template.scsi_type}"

    network_interface {
      network_id       = "${data.vsphere_network.network.id}"
      adapter_type     = "${data.vsphere_virtual_machine.template.network_interface_types[0]}"
    }

    disk {
      label            = "disk0"
      size             = "${data.vsphere_virtual_machine.template.disks.0.size}"
      eagerly_scrub    = "${data.vsphere_virtual_machine.template.disks.0.eagerly_scrub}"
      thin_provisioned = "${data.vsphere_virtual_machine.template.disks.0.thin_provisioned}"
    }

    clone {
      template_uuid    = "${data.vsphere_virtual_machine.template.id}"
      linked_clone     = "True"

      customize {
        linux_options {
          host_name    = "control${count.index+1}"
          domain       = "${var.clustername}"
        }

        network_interface {
          ipv4_address = "${var.mgmt-subnet}60"
          ipv4_netmask = 24
        }

        # network_interface {
        #   ipv4_address = "${var.provider-subnet}60"
        #   ipv4_netmask = 24
        # }

        ipv4_gateway   = "192.168.1.1"
        dns_server_list = ["8.8.8.8"]
      }
    }
  }

  ## Compute
  resource "vsphere_virtual_machine" "compute" {
    count            = "${var.compute_count}"
    # name             = "${var.clustername}-c1a${count.index}"
    name             = "${var.clustername}-C1${element(var.nodenames, count.index % length(var.nodenames))}"
    resource_pool_id = "${data.vsphere_compute_cluster.compute_cluster.resource_pool_id}"
    datastore_id     = "${data.vsphere_datastore.datastore.id}"
    folder           = "${var.clustername}/Compute"
    num_cpus         = 2
    memory           = 1024
    guest_id         = "${data.vsphere_virtual_machine.template.guest_id}"
    scsi_type        = "${data.vsphere_virtual_machine.template.scsi_type}"

    network_interface {
      network_id       = "${data.vsphere_network.network.id}"
      adapter_type     = "${data.vsphere_virtual_machine.template.network_interface_types[0]}"
    }

    disk {
      label            = "disk0"
      size             = "${data.vsphere_virtual_machine.template.disks.0.size}"
      eagerly_scrub    = "${data.vsphere_virtual_machine.template.disks.0.eagerly_scrub}"
      thin_provisioned = "${data.vsphere_virtual_machine.template.disks.0.thin_provisioned}"
    }

    clone {
      template_uuid    = "${data.vsphere_virtual_machine.template.id}"
      linked_clone     = "True"

      customize {
        linux_options {
          host_name    = "C1${element(var.nodenames, count.index % length(var.nodenames))}"
          domain       = "${var.clustername}"
        }

        network_interface {
          ipv4_address = "${var.mgmt-subnet}6${count.index+1}"
          ipv4_netmask = 24
        }

        # network_interface {
        #   ipv4_address = "${var.priv-subnet}6${count.index}"
        #   ipv4_netmask = 24
        # }
        dns_server_list = ["8.8.8.8"]
        ipv4_gateway   = "192.168.1.1"
      }
    }
  }