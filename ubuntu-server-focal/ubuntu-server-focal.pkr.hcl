# Define input variables that will be used to configure the Proxmox connection
variable "proxmox_api_url" {
    type = string
}

variable "proxmox_api_token_id" {
    type = string
}

variable "proxmox_api_token_secret" {
    type = string
    sensitive = true  # Marks this variable as sensitive - won't be shown in logs
}

# Main source block that defines the VM template configuration
source "proxmox" "ubuntu-server-focal-template" {
    # Connection settings for Proxmox API
    proxmox_url = "${var.proxmox_api_url}"  # URL to connect to Proxmox
    username = "${var.proxmox_api_token_id}"  # API token ID
    token = "${var.proxmox_api_token_secret}"  # API token secret
    insecure_skip_tls_verify = true  # Skip SSL verification
    
    # Basic VM settings
    node = "10.0.40.10"  # Proxmox node name
    vm_id = "5000"  # Unique ID for the VM
    vm_name = "ubuntu-server-focal-template"  # Name of the VM template
    template_description = "Ubuntu Server Focal (22.04) Image"  # Template description

    # ISO configuration
    iso_file = "nfs-proxmox-iso:iso/ubuntu-20.04.6-live-server-amd64.iso"  # Path to ISO file
    iso_storage_pool = "cp"  # Storage pool for ISO
    unmount_iso = true  # Remove ISO after installation

    # VM hardware settings
    qemu_agent = true  # Enable QEMU guest agent
    scsi_controller = "virtio-scsi-pci"  # Type of SCSI controller

    # Disk configuration
    disks {
        disk_size = "20G"  # Size of the virtual disk
        format = "raw"  # Disk format
        storage_pool = "local-lvm"  # Storage pool for disk
        storage_pool_type = "lvm"  # Type of storage pool
        type = "virtio"  # Disk driver type
    }

    # CPU and Memory settings
    cores = "1"  # Number of CPU cores
    memory = "4096"  # RAM in MB

    # Network configuration
    network_adapters {
        model = "virtio"  # Network adapter type
        bridge = "vmbr0"  # Network bridge
        firewall = "false"  # Disable firewall
    } 

    # Cloud-Init configuration
    cloud_init = true  # Enable cloud-init
    cloud_init_storage_pool = "local-lvm"  # Storage for cloud-init

    # Boot and installation settings
    boot_command = [
        "<esc><wait>",
        "<esc><wait>",
        "<f6><wait>",
        "<esc><wait>",
        "<bs><bs><bs><bs><bs>",
        "autoinstall ds=nocloud-net;s=http://{{ .HTTPIP }}:{{ .HTTPPort }}/ ",
        "--- <enter>"
    ]
    boot = "c"  # Boot mode
    boot_wait = "30s"  # Increase from 5s to 30s

    # HTTP server settings for autoinstall
    http_directory = "http"  # Directory containing autoinstall files

    # HTTP server bind address
    # - build.Host is a special variable that represents the host machine's IP address - useful if using DHCP to assign IP
    # - replace the variable with the actual IP address of the host machine if on fixed IP
    # http_bind_address = "${build.Host}"
    http_port_min = 8802  # HTTP server port range
    http_port_max = 8802

    # SSH configuration
    ssh_username = "fs"  # SSH user for provisioning
    ssh_private_key_file = "~/.ssh/fs_home_rsa"  # SSH key file
    ssh_timeout = "55m"  # SSH connection timeout
}

# Build block defines what happens after VM creation
build {
    name = "ubuntu-server-focal"
    sources = ["source.proxmox.ubuntu-server-focal-template"]

    # Provisioners run in order to prepare the template
    provisioner "shell" {
        # Commands to clean up the VM and prepare for templating
        inline = [
            "while [ ! -f /var/lib/cloud/instance/boot-finished ]; do echo 'Waiting for cloud-init...'; sleep 1; done",
            "sudo rm /etc/ssh/ssh_host_*",
            "sudo truncate -s 0 /etc/machine-id",
            "sudo apt -y autoremove --purge",
            "sudo apt -y clean",
            "sudo apt -y autoclean",
            "sudo cloud-init clean",
            "sudo rm -f /etc/cloud/cloud.cfg.d/subiquity-disable-cloudinit-networking.cfg",
            "sudo sync"
        ]
    }

    # File provisioner to copy cloud-init configuration
    provisioner "file" {
        source = "files/99-pve.cfg"
        destination = "/tmp/99-pve.cfg"
    }

    # Final shell provisioner to move cloud-init config to proper location
    provisioner "shell" {
        inline = [ "sudo cp /tmp/99-pve.cfg /etc/cloud/cloud.cfg.d/99-pve.cfg" ]
    }
}
