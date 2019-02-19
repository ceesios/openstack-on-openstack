variable "azs" {
  description = "Run the EC2 Instances in these Availability Zones"
  type = "list"
  default = ["AMS-EQ1", "AMS-EQ3", "AMS-EU4"]
}
variable "image_name"  { default = "Ubuntu 18.04 (ipv4-only)", type = "string"}
# variable "image_name"  { default = "Ubuntu 18.04 (LTS)", type = "string"}
variable "flavor_id" { default = "2016", type = "string"}
variable "key_pair" {default="", type="string"}
variable "default_security_groups" { default = ["default", "allow-all"], type = "list"}
variable "floating_ip_pool" { default = "floating", type = "string"}
variable "floating_ip_network_id" { default = "f9c73cd5-9e7b-4bfd-89eb-c2f4f584c326", type = "string"}

variable "clustername" { default = "os_Lab", type = "string"}
variable "mgmt-cidr" { default = "10.0.0.0/16" }
variable "priv-cidr" { default = "10.1.0.0/16" }
variable "dns_nameservers" { default = "8.8.8.8" }
variable "provider-net-name" { default = "cust-public" }
variable "provider-subnet" { default = "93.191.134.32/29" }
variable "provider-gw" { default = "93.191.134.33" }

variable "control_count" {default = 1}
variable "compute_count" {default = 3}
variable "ceph_count" {default = 3}
variable "swift_count" {default = 3}
variable "nodenames" { default = ["A1", "B1", "C1", "A2", "B2", "C2", "A3", "B3", "C3"]}

