# Ubuntu Server Focal
# ---
# Packer Template to create an Ubuntu Server (Focal) on Proxmox

#* Variable Definitions
variable "proxmox_api_url" {
    type = string
}
variable "proxmox_api_token_id" {
    type = string
}
variable "proxmox_api_token_secret" {
    type = string
    sensitive = true
}

#* Resource Definiation for the VM Template
source "proxmox" "ubuntu-server-focal" {

    # Proxmox Connection Settings
    proxmox_url = "${var.proxmox_api_url}"
    username = "${var.proxmox_api_token_id}"
    token = "${var.proxmox_api_token_secret}"
    # (Optional) Skip TLS Verification
    insecure_skip_tls_verify = true
    # VM General Settings
    node = "pve-0"
    vm_id = "5003"
    vm_name = "ubuntu-server-focal-docker"
    template_description = "Ubuntu Server Focal Image"

    # VM OS Settings
    # (Option 1) Local ISO File
    iso_file = "qnap-nfs:iso/ubuntu-20.04.5-live-server-amd64.iso"
    # - or -
    # # (Option 2) Download ISO
    # iso_url = "https://releases.ubuntu.com/20.04/ubuntu-20.04.3-live-server-amd64.iso"
    # iso_checksum = "f8e3086f3cea0fb3fefb29937ab5ed9d19e767079633960ccb50e76153effc98"
    iso_storage_pool = "qnap-nfs"
    unmount_iso = true

    # VM System Settings
    qemu_agent = true

    # VM Hard Disk Settings
    scsi_controller = "virtio-scsi-pci"

    disks {
        disk_size = "20G"
        format = "qcow2"
        storage_pool = "data-slow"
        storage_pool_type = "directory"
        type = "virtio"
    }

    # VM CPU Settings
    cores = "1"

    # VM Memory Settings
    memory = "2048"

    # VM Network Settings
    network_adapters {
        model = "virtio"
        bridge = "vmbr0"
        firewall = "false"
    }

    # VM Cloud-Init Settings
    cloud_init = true
    cloud_init_storage_pool = "data-slow"

    # PACKER Boot Commands
    boot_command = [
        "<esc><wait><esc><wait>",
        "<f6><wait><esc><wait>",
        "<bs><bs><bs><bs><bs>",
        "autoinstall ds=nocloud-net;s=http://{{ .HTTPIP }}:{{ .HTTPPort }}/ ",
        "--- <enter>"
    ]
    boot = "c"
    boot_wait = "5s"

    # PACKER Autoinstall Settings
    http_directory = "http"
    # (Optional) Bind IP Address and Port
    http_bind_address = "10.0.0.4" # "0.0.0.0" # ? ip from ifconfig
    http_port_min = 8802
    http_port_max = 8802

    ssh_username = "fabrice"

    # (Option 1) Add your Password here
    # ssh_password = "<your-password>"
    # - or -
    # (Option 2) Add your Private SSH KEY file here
    ssh_private_key_file = "~/.ssh/id_ed25519"

    # Raise the timeout, when installation takes longer
    ssh_timeout = "20m"
}

# Build Definition to create the VM Template
build {

    name = "ubuntu-server-focal-docker"
    sources = ["source.proxmox.ubuntu-server-focal"]

    # Provisioning the VM Template for Cloud-Init Integration in Proxmox #1
    provisioner "shell" {
        inline = [
            "while [ ! -f /var/lib/cloud/instance/boot-finished ]; do echo 'Waiting for cloud-init...'; sleep 1; done",
            "sudo rm /etc/ssh/ssh_host_*",
            "sudo truncate -s 0 /etc/machine-id",
            "sudo apt -y autoremove --purge 2>/dev/null",
            "sudo apt -y clean 2>/dev/null",
            "sudo apt -y autoclean 2>/dev/null",
            "sudo cloud-init clean",
            "sudo rm -f /etc/cloud/cloud.cfg.d/subiquity-disable-cloudinit-networking.cfg",
            "sudo sync"
        ]
    }

    # Provisioning the VM Template for Cloud-Init Integration in Proxmox #2
    provisioner "file" {
        source = "files/99-pve.cfg"
        destination = "/tmp/99-pve.cfg"
    }

    # Provisioning the VM Template for Cloud-Init Integration in Proxmox #3
    provisioner "shell" {
        inline = [ "sudo cp /tmp/99-pve.cfg /etc/cloud/cloud.cfg.d/99-pve.cfg" ]
    }

    # Provisioning the VM Template with Docker Installation #4
    provisioner "shell" {
        inline = [
            "sudo apt-get install -y ca-certificates curl gnupg lsb-release",
            "curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg",
            "echo \"deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable\" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null",
            "sudo apt-get -y update",
            "sudo apt-get install -y docker-ce docker-ce-cli containerd.io"
        ]
    }
}
