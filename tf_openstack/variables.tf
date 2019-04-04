## CloudVPS pub options
variable "azs" {
  description = "Run Instances in these Availability Zones"
  type = "list"
  default = ["AMS-EQ1", "AMS-EQ3", "AMS-EU4"]
}
variable "image_name"       { default = "Ubuntu 18.04 (LTS)", type = "string"}
variable "small_flavor_id"  { default = "1001", type = "string"} #Standad 1
variable "medium_flavor_id" { default = "2004", type = "string"} #Small HD 4GB
variable "flavor_id"        { default = "2016", type = "string"} #Small HD 16GB
variable "security_groups"  { default = ["default"], type = "list"}
variable "floating_ip_pool" { default = "floating", type = "string"}
variable "floating_net_id"  { default = "f9c73cd5-9e7b-4bfd-89eb-c2f4f584c326", type = "string"}

## Setup specific options (should be in your tfvars)
variable "key_pair"         { default = "", type="string" }
variable "clustername"      { default = "os_Lab", type = "string"}

## Dns nameservers
variable "dns_nameservers"  { default = "8.8.8.8" }

## Mgmt and priv-net will be created with these cidr ranges
variable "mgmt_cidr"        { default = "10.0.0.0/16" }
variable "priv_cidr"        { default = "10.1.0.0/16" }

## Public net, should be created outside of TF when using BYOIP.
## Set create_pub_net to false if you have BYOIP
variable "create_pub_net"   { default = true }
variable "pub_net_name"     { default = "pub-net" }
variable "pub_cidr"         { default = "10.2.0.0/16" }
variable "pub_gw"           { default = "10.2.0.1/16" }

variable "control_count"    { default = 1 }
variable "compute_count"    { default = 3 }
variable "gnocchi_api_count" { default = 3 }
variable "metricd_count"    { default = 3 }
variable "ceph_mon_count"   { default = 3 }
variable "ceph_s_node_count" { default = 3 }
#variable "swift_count"      { default = 3 }
variable "nodenames"        { default = ["A1", "B1", "C1", "A2", "B2", "C2", "A3", "B3", "C3"] }
