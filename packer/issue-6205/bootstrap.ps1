$ErrorActionPreference = 'Stop'
$tmp_dir = "$env:SystemDrive\temp"
$script_dir = Split-Path -Path $($script:MyInvocation.MyCommand.Path) -Parent

Function Write-Log($message, $level="INFO") {
    # Poor man's implementation of Log4Net
    $date_stamp = Get-Date -Format s
    $log_entry = "$date_stamp - $level - $message"
    $log_file = "$tmp_dir\bootstrap.log"
    Write-Host $log_entry
    Add-Content -Path $log_file -Value $log_entry
}

Function Reboot-AndResume($action) {
    # need to reboot the server and rerun this script at the next action
    $command = "$env:SystemDrive\Windows\System32\WindowsPowerShell\v1.0\powershell.exe $($script:MyInvocation.MyCommand.Path) '$action'"
    $reg_key = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce"
    $reg_property_name = "bootstrap"
    Set-ItemProperty -Path $reg_key -Name $reg_property_name -Value $command
    Write-Log -message "rebooting server and continuing bootstrap.ps1 with action '$action'"
    if (Get-Command -Name Restart-Computer -ErrorAction SilentlyContinue) {
        Restart-Computer -Force
        Start-Sleep -Seconds 10
    } else {
        # PS v1 (Server 2008) doesn't have the cmdlet Restart-Computer, use el-traditional
        shutdown /r /t 0
        Start-Sleep -Seconds 10
    }
}

Function Run-Process($executable, $arguments) {
    $process = New-Object -TypeName System.Diagnostics.Process
    $psi = $process.StartInfo
    $psi.FileName = $executable
    $psi.Arguments = $arguments
    Write-Log -message "starting new process '$executable $arguments'"
    $process.Start() | Out-Null
    
    $process.WaitForExit() | Out-Null
    $exit_code = $process.ExitCode
    Write-Log -message "process completed with exit code '$exit_code'"

    return $exit_code
}

Function Extract-Zip($zip, $dest) {
    Write-Log -message "extracting '$zip' to '$dest'"
    try {
        Add-Type -AssemblyName System.IO.Compression.FileSystem > $null
        $legacy = $false
    } catch {
        $legacy = $true
    }

    if ($legacy) {
        try {
            $shell = New-Object -ComObject Shell.Application
            $zip_src = $shell.NameSpace($zip)
            $zip_dest = $shell.NameSpace($dest)
            $zip_dest.CopyHere($zip_src.Items(), 1044)
        } catch {
            Write-Log -message "failed to extract zip file: $($_.Exception.Message)" -level "ERROR"
            throw $_
        }
    } else {
        try {
            [System.IO.Compression.ZipFile]::ExtractToDirectory($zip, $dest)
        } catch {
            Write-Log -message "failed to extract zip file: $($_.Exception.Message)" -level "ERROR"
            throw $_
        }
    }
}

$action = $args[0]
if (-not (Test-Path -Path $tmp_dir)) {
    New-Item -Path $tmp_dir -ItemType Directory | Out-Null
}
Write-Log -message "starting bootstrap.ps1 with action '$action'"

$bootstrap_actions = @(
    @{
        name = "Configure WinRM"
        action = "winrm"
    }
)

$actions = @()
if ($action) {
    $add_action = $false
    foreach ($bootstrap_action in $bootstrap_actions) {
        if ($bootstrap_action.name -eq $action) {
            $add_action = $true
        }

        if ($add_action) {
            $actions += $bootstrap_action
        }
    }
} else {
    $actions = $bootstrap_actions
}

for ($i = 0; $i -lt $actions.Count; $i++) {
    $current_action = $actions[$i]
    $next_action = $null
    if ($i -lt ($actions.Count - 1)) {
        $next_action = $actions[$i + 1]
    }

    switch($current_action.action) {
        "install" {
            Write-Log -message "Installing $($current_action.name)"
            if ($current_action.file) {
                $src = $current_action.file
            } else {
                $src = $current_action.url.Split("/")[-1]
            }
            $src = "$script_dir\$src"
            $exit_code = Run-Process -executable $src -arguments $current_action.arguments
            if ($exit_code -eq 3010) {
                Reboot-AndResume -action $next_action.name
            } elseif ($exit_code -ne 0) {
                $error_message = "failed to install $($current_action.name): exit code $exit_code"
                Write-Log -message $error_message -level "ERROR"
                throw $error_message
            }
        }
        "install-zip" {
            Write-Log -message "Installing $($current_action.name)"
            if ($current_action.file) {
                $src = $current_action.file
            } else {
                $src = $current_action.url.Split("/")[-1]
            }
            $zip_src = "$script_dir\$src"
            Extract-Zip -zip $zip_src -dest $tmp_dir
            $install_file = Get-Item -Path "$tmp_dir\$($current_action.zip_file_pattern)"
            if ($install_file -eq $null) {
                $error_message = "unable to find extracted file of pattern $($current_action.zip_file_pattern) for installing $($current_action.name)"
                Write-Log -message $error_message -level "ERROR"
                throw $error_message
            }

            $exit_code = Run-Process -executable $install_file -arguments $current_action.arguments
            if ($exit_code -eq 3010) {
                Reboot-AndResume -action $next_action.name
            } elseif ($exit_code -ne 0) {
                $error_message = "failed to install $($current_action.name): exit code $exit_code"
                Write-Log -message $error_message -level "ERROR"
                throw $error_message
            }
        }
        "winrm" {
            Write-Log -message "configuring WinRM listener to work over 5985 with Basic auth"
            &winrm.cmd quickconfig -q
            Set-Item -Path WSMan:\localhost\Service\Auth\Basic -Value $true
            Set-Item -Path WSMan:\localhost\Service\AllowUnencrypted -Value $true
            $winrm_service = Get-Service -Name winrm
            if ($winrm_service.Status -ne "Running") {
                try {
                    Start-Service -Name winrm
                } catch {
                    $error_message = "failed to start WinRM service required by Ansible"
                    Write-Log -message $error_message -level "ERROR"
                    throw $error_message
                }
            }
    
            Write-Log -message "enabling RDP"
            $rdp_wmi = Get-CimInstance -ClassName Win32_TerminalServiceSetting -Namespace root\CIMV2\TerminalServices
            $rdp_enable = $rdp_wmi | Invoke-CimMethod -MethodName SetAllowTSConnections -Arguments @{ AllowTSConnections = 1; ModifyFirewallException = 1 }
            if ($rdp_enable.ReturnValue -ne 0) {
                $error_message = "failed to change RDP connection settings, error code: $($rdp_enable.ReturnValue)"
                Write-Log -message $error_message -level "ERROR"
                throw $error_message
            }
    
            Write-Log -message "enabling NLA authentication for RDP"
            $nla_wmi = Get-CimInstance -ClassName Win32_TSGeneralSetting -Namespace root\CIMV2\TerminalServices
            $nla_wmi | Invoke-CimMethod -MethodName SetUserAuthenticationRequired -Arguments @{ UserAuthenticationRequired = 1 } | Out-Null
            $nla_wmi = Get-CimInstance -ClassName Win32_TSGeneralSetting -Namespace root\CIMV2\TerminalServices
            if ($nla_wmi.UserAuthenticationRequired -ne 1) {
                $error_message = "failed to enable NLA"
                Write-Log -message $error_message -level "ERROR"
                throw $error_message
            }
        }
    }
}

Write-Log -message "bootstrap.ps1 complete"