# LabBicep

[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

## Description

LabBicep is a series of bicep templates to automatically deploy a lab environment for demoing Microsoft security products in Azure. It is intended to be used in conjunction with a Microsoft365 tenant hydrated with users and content.
It deploys:
- VNet with 2 subnets
- OPNSense as a firewall
- Windows 11 VM w/ public IP to do post-install configuration of resources
- Route tables directing VM traffic through OPNSense
- Domain Controller
- Log Analytics w/ Sentinel


## Table of Contents

- [Installation](#installation)
- [Usage](#usage)
- [Contributing](#contributing)
- [License](#license)
- [Contact](#contact)

## Installation

Compile DSC files (if needed)
1. `Install-Module az,xStorage,xActiveDirectory,xNetworking,PSDesiredStateConfiguration,xPendingReboot`
2. `Import-Module Az`
3. `Publish-AzVMDscConfiguration .\Scripts\ConfigureDC.ps1 -OutputArchivePath .\ConfigureDC.zip`

If you plan to provision the OPNSense firewall, you will need to accept the FreeBSD license terms using the following command: `az vm image terms accept --publisher "thefreebsdfoundation" --offer "freebsd-13_1" --plan "13_1-release"`

If you plan to provision a domain controller, you will need to pre-provision a user-assigned managed identity, and grant it User.Read.All (preferably using a custom Entra role)

Create Bicep param file and populate with required parameters.

## Usage

Instructions on how to use the project and any relevant examples.

## Contributing

Guidelines for contributing to the project.

## License

This project is licensed under the [MIT License](LICENSE).

## Contact

- Name: David Hart
- GitHub: [Hartd92](https://github.com/hartd92)
