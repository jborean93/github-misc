# GitHub Issue/PR

Test for [6315](https://github.com/hashicorp/packer/issues/6315)

Issues when running the latest Packer version (1.2.4) with Hyper-V building
a FreeBSD guest. Suspects it relates to a bad change in
https://github.com/hashicorp/packer/pull/6219.

Packer scripts have been modified from https://github.com/lavabit/robox.


# Requirements

* Packer
* Hyper-V


# Steps

Run the following command

```
export PACKER_LOG=1
export PACKER_LOG_PATH=packerlog.txt
packer build -force packer.json
```


# Artifacts

* `packerlog.txt`: The debug logs from the run


# Analysis

The details are due to the changes made in
https://github.com/hashicorp/packer/pull/6219. The root cause is that the
function in `IpAddress` of `common/powershell/hyperv/hyperv.go`. Before the
function was

```
function Get-IpAddressOld
{
    param([string]$mac, [int]$addressIndex)
    try {
        $ip = Hyper-V\Get-Vm | %{$_.NetworkAdapters} | ?{$_.MacAddress -eq $mac} | %{$_.IpAddresses[$addressIndex]}

        if($ip -eq $null) {
            return ""
        }
    } catch {
        return ""
    }
    $ip
}
```

and now it is

```
function Get-IpAddressNew
{
    param([string]$mac, [int]$addressIndex)
    try {
        $vm = Hyper-V\Get-VM | ?{$_.NetworkAdapters.MacAddress -eq $mac}
        if ($vm.NetworkAdapters.IpAddresses) {
            $ip = $vm.NetworkAdapters.IpAddresses[$addressIndex]
        } else {
            $vm_info = Get-CimInstance -ClassName Msvm_ComputerSystem -Namespace root\virtualization\v2 -Filter "ElementName='$($vm.Name)'"
            $ip_details = (Get-CimAssociatedInstance -InputObject $vm_info -ResultClassName Msvm_KvpExchangeComponent).GuestIntrinsicExchangeItems | %{ [xml]$_ } | ?{ $_.SelectSingleNode("/INSTANCE/PROPERTY[@NAME='Name']/VALUE[child::text()='NetworkAddressIPv4']") }
            if ($null -eq $ip_details) {
                return ""
            }
            $ip_addresses = $ip_details.SelectSingleNode("/INSTANCE/PROPERTY[@NAME='Data']/VALUE/child::text()").Value
            $ip = ($ip_addresses -split ";")[0]
        }
    } catch {
        return ""
    }
    $ip
}
```

When running that manually on a FreeBSD host in Hyper-V you get the following
output

```
PS C:\WINDOWS\system32> $mac = "00155D01075A"
PS C:\WINDOWS\system32> Get-IpAddressOld -mac $mac -addressIndex 0
192.168.1.30
PS C:\WINDOWS\system32> Get-IpAddressNew -mac $mac -addressIndex 0
1
```

We can see that in the debug output we get the following lines until a timeout

```
2018/06/18 13:49:00 packer.exe: 2018/06/18 13:49:00 [DEBUG] TCP connection to SSH ip/port failed: dial tcp: lookup 1: no such host
```

The new code is returning `1` ([] on a string get's the char at the index like
.substring()) instead of the full IP causing the issue.

To fix this issue and still retain the new functionality added with 6219, the
function should set `IPAddresses` as an array if it isn't already.

When using the below we get a working build.

```
function Get-IpAddressNewFixed
{
    param([string]$mac, [int]$addressIndex)
    try {
        $vm = Hyper-V\Get-VM | ?{$_.NetworkAdapters.MacAddress -eq $mac}
        if ($vm.NetworkAdapters.IpAddresses) {
            $ipAddresses = $vm.NetworkAdapters.IPAddresses
            if ($ipAddresses -isnot [array]) {
                $ipAddresses = @($ipAddresses)
            }
            $ip = $ipAddresses[$addressIndex]
        } else {
            $vm_info = Get-CimInstance -ClassName Msvm_ComputerSystem -Namespace root\virtualization\v2 -Filter "ElementName='$($vm.Name)'"
            $ip_details = (Get-CimAssociatedInstance -InputObject $vm_info -ResultClassName Msvm_KvpExchangeComponent).GuestIntrinsicExchangeItems | %{ [xml]$_ } | ?{ $_.SelectSingleNode("/INSTANCE/PROPERTY[@NAME='Name']/VALUE[child::text()='NetworkAddressIPv4']") }
            if ($null -eq $ip_details) {
                return ""
            }
            $ip_addresses = $ip_details.SelectSingleNode("/INSTANCE/PROPERTY[@NAME='Data']/VALUE/child::text()").Value
            $ip = ($ip_addresses -split ";")[0]
        }
    } catch {
        return ""
    }
    $ip
}
```
