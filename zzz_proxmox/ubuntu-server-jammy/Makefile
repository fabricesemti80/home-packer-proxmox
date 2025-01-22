.PHONY: default
default: validate

.PHONY: validate
validate:
	packer validate ubuntu-server-jammy.pkr.hcl

.PHONY: build
build:
	packer build ubuntu-server-jammy.pkr.hcl
