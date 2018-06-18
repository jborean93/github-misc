# GitHub Issue/PR

Test for [6219](https://github.com/hashicorp/packer/pull/6219)

# Requirements

* Packer changes in the PR compiled so that it can detect the IP address of the guest
* [ImgBurn](http://www.imgburn.com/) setup and installed to the path so the secondary.iso file can be created
* Hyper-V roles installed for Packer to use

_Note: If you have Chocolatey installed, you can install this with `choco.exe install -y imgburn`_

# Steps

Run the following commands in PowerShell

```powershell
.\setup.ps1
$env:PACKER_LOG=1
$env:PACKER_LOG_PATH="packerlog.txt"
packer.exe build -force packer.json
```

_Note: You may need to reference the full path to the packer executable that was compiled to ensure you use the newer changes_

# Artifacts

* `iso/*`: Various files downloaded with `setup.ps1` used in the bootstrapping process
* `7601.17514.101119-1850_x64fre_server_eval_en-us-GRMSXEVAL_EN_DVD`: The Server 2008 R2 iso downloaded with `setup.ps1`
* `packer-stdout.txt`: The stdout of the packer process
