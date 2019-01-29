variable "key_pair" {default="", type="string"}
variable "vsphere_user" {default="", type="string"}
variable "vsphere_pass" {default="", type="string"}
variable "vsphere_server" {default="", type="string"}
variable "clustername" { default = "OS_Lab", type = "string"}
variable "mgmt-subnet" { default = "192.168.1." }
variable "provider-subnet" { default = "192.168.2." }
variable "priv-subnet" { default = "192.168.3." }
variable "control_count" {default = 1}
variable "compute_count" {default = 3}
variable "ceph_count" {default = 3}
variable "swift_count" {default = 3}
variable "nodenames" { default = ["A1", "B1", "C1", "A2", "B2", "C2", "A3", "B3", "C3"]}

