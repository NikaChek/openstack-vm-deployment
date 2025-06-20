// internal network

resource "openstack_networking_network_v2" "internal_network" {
  name = "internal-network"
  admin_state_up = true
}

resource "openstack_networking_subnet_v2" "internal_subnet" {
  name            = "internal-subnet"
  network_id      = openstack_networking_network_v2.internal_network.id
  cidr            = "192.168.100.0/24"
  ip_version      = 4
}


// floating ip

resource "openstack_networking_floatingip_v2" "fip_1" {
  pool = "Internet"
}
 

// image

data "openstack_images_image_v2" "ubuntu" {
  name        = "ubuntu-20.04"
}

data "openstack_images_image_v2" "ubuntu_22_04" {
  name        = "ubuntu-22.04"
}

//vm 1

resource "openstack_compute_instance_v2" "vm_1" {
  name            = "vm-1"
  flavor_name     = "c1.micro"
  key_pair        = "atomlab_vm"
  security_groups = ["ssh", "default", "icmp", "http", "https"]

  block_device {
    uuid                  = data.openstack_images_image_v2.ubuntu_22_04.id
    source_type           = "image"
    destination_type      = "volume"
    volume_size           = 50
    boot_index            = 0
    delete_on_termination = true
  }

  network {
    name = openstack_networking_network_v2.internal_network.name
    fixed_ip_v4 = "192.168.100.101"
  }

  user_data = file("cloud-init-static-ip/cloud-init-static-ip-vm-1.yaml")
}

resource "openstack_compute_floatingip_associate_v2" "fip_1" {
  floating_ip = openstack_networking_floatingip_v2.fip_1.address
  instance_id = openstack_compute_instance_v2.vm_1.id
  
  depends_on = [openstack_networking_router_interface_v2.router_interface]
}


// vm 2

resource "openstack_compute_instance_v2" "vm_2" {
  name            = "vm-2"
  flavor_name     = "c1.micro"
  key_pair        = "atomlab_vm"
  security_groups = ["default", "ssh", "icmp",  "http", "https"]

  block_device {
    uuid                  = data.openstack_images_image_v2.ubuntu_22_04.id
    source_type           = "image"
    destination_type      = "volume"
    volume_size           = 4
    boot_index            = 0
    delete_on_termination = true
  }

  network {
    name = openstack_networking_network_v2.internal_network.name
    fixed_ip_v4 = "192.168.100.102"
  }

  user_data = file("cloud-init-static-ip/cloud-init-static-ip-vm-2.yaml")
}


// vm 3

resource "openstack_compute_instance_v2" "vm_3" {
  name            = "vm-3"
  flavor_name     = "c1.micro"
  key_pair        = "atomlab_vm"
  security_groups = ["default", "ssh", "icmp",  "http", "https"]

  block_device {
    uuid                  = data.openstack_images_image_v2.ubuntu_22_04.id
    source_type           = "image"
    destination_type      = "volume"
    volume_size           = 4
    boot_index            = 0
    delete_on_termination = true
  }

  network {
    name = openstack_networking_network_v2.internal_network.name
    fixed_ip_v4 = "192.168.100.103"
  }

  user_data = file("cloud-init-static-ip/cloud-init-static-ip-vm-3.yaml")
}


// router

resource "openstack_networking_router_v2" "router" {
  name                = "my-router"
  admin_state_up      = true
  external_network_id = var.external_network_id
}

resource "openstack_networking_router_interface_v2" "router_interface" {
  router_id = openstack_networking_router_v2.router.id
  subnet_id = openstack_networking_subnet_v2.internal_subnet.id
}

