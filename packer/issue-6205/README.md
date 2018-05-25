# GitHub Issur/PR

Test for [6285](https://github.com/hashicorp/packer/issues/6205)

Issues when running the winrm connector with NTLM auth. After investigation it
doesn't seeem to be a valid issue. I believe the cause is because the end user
never enabled unencrypted authentication and so NTLM always failed (returned
401).

# Requirements

* Packer
* VirtualBox
* WireShark (if you want to capture the network traffic)

# Steps

Run the following command

```
export PACKER_LOG=1
export PACKER_LOG_PATH=packerlog.txt
packer build -force packer.json
```

# Artifacts

* `packerlog.txt`: The debug logs from the run
* `wireshark.pcagng`: A manual packet capture over the forwarded WinRM port to illustrate the issue


# Analysis

Packer works with NTLM authentication, only when `AllowUnencrypted` is set to
`True` on the Windows host. When set to `False`, Packer's WinRM/NTLM library
does not encrypt the message payload and will fail with a 401 error.

When looking at the Packets you can see that the NTLM Negotiate message is
"malformed" in Wireshark but is still valid as Windows responds with the
Challenge response. The error seems to be occurring because the WinRM message
is not encrypted.

Frames of note in Wireshark output:
* `708-714`: NTLM auth was sent with plaintext WinRM payload but server responds with 401
* `736-744`: NTLM auth was sentwith plaintext WinRM payload and the server responds with 200 (this is just after the host was set to allow unencrypted messages)
* `766-772`: Ansible example that shows the same process but with the correct NTLM Negotiate message and encrypted payload
