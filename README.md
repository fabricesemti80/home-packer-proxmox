# Notes

Notes to future-self:

## User-Data

These files are containing the settings that `cloud-init` will use to configure the VM.

- localization (mostly in my case GB)
- my user name
- my public ssh key

These need to be updated, if neccesary

## Credentials

Obviously these are not public, but a template for this:

```hcl
cat .../proxmox-packer-00/proxmox/credentials.pkr.hcl
proxmox_api_url = "https://<PROXMOX-ADDRESS>:8006/api2/json"
proxmox_api_token_id = "<API-ID>"
proxmox_api_token_secret = "<API-SECRET>"
```

## Packer HCL-s

These contain the instructions for the build. Most are straight-forward, I only note the ones that are not

- update proxmox `node` if neccesary
- `vm_id` - I decided to ID VM templates from 200 (by default Proxmox starts to allocate ID-s from 100, and it is unlikely I will reach 100 VM-s, so it is safe this way); all new tempalte will have an incremental number
- `iso_storage_pool` - this is where the template will be stored; I use an NFS storage from a NAS to keep these
- `storage_pool` and  `cloud_init_storage_pool` = for these, I use a hdd-based raid array, that I named `data-slow` (for live- production VM-s I currently have a much smaller SSD, that is named `data-fast`)
- `http_bind_address` - this is an IP on my system, allowing packer to bind the webserver to; tried with 0.0.0.0 but did not work, so explicitly declared it
- `ssh_private_key_file` - reference to my private ssh key on the workstation; have to match to the public key defined in the  user-data file

## Refernces

<https://youtu.be/1nf3WOEFq1Y>

<https://docs.powerhost.io/?docs=proxmox-cloud-init-template-guide>