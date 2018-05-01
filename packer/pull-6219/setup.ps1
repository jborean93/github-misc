# downloads the required binary files and packages it up as an ISO
# requires imgburn.exe to be available on the path, install with
#     choco.exe install imgburn

Function New-Process($executable, $arguments) {
    $process = New-Object -TypeName System.Diagnostics.Process
    $psi = $process.StartInfo
    $psi.FileName = $executable
    $psi.Arguments = $arguments
    $process.Start() > $null
    $process.WaitForExit() > $null
}

$files = @(
    @{
        url = "https://download.microsoft.com/download/7/5/E/75EC4E54-5B02-42D6-8879-D8D3A25FBEF7/7601.17514.101119-1850_x64fre_server_eval_en-us-GRMSXEVAL_EN_DVD.iso"
        dest = "7601.17514.101119-1850_x64fre_server_eval_en-us-GRMSXEVAL_EN_DVD.iso"
    },
    @{
        url = "http://download.microsoft.com/download/B/A/4/BA4A7E71-2906-4B2D-A0E1-80CF16844F5F/dotNetFx45_Full_x86_x64.exe"
        dest = "iso\dotNetFx45_Full_x86_x64.exe"
    },
    @{
        url = "https://download.microsoft.com/download/E/7/6/E76850B8-DA6E-4FF5-8CCE-A24FC513FD16/Windows6.1-KB2506143-x64.msu"
        dest = "iso\Windows6.1-KB2506143-x64.msu"
    },
    @{
        url = "https://hotfixv4.trafficmanager.net/Windows%207/Windows%20Server2008%20R2%20SP1/sp2/Fix467402/7600/free/463984_intl_x64_zip.exe"
        dest = "iso\KB2842230-wmfv3.zip"
    },
    @{
        url = "http://download.windowsupdate.com/windowsupdate/redist/standalone/7.6.7600.320/windowsupdateagent-7.6-x64.exe"
        dest = "iso\windowsupdateagent-7.6-x64.exe"
    }
)

$current_dir = $PSScriptRoot
$iso_path = "$current_dir\iso"
if (-not (Test-Path -Path $iso_path)) {
    New-Item -Path $iso_path -ItemType Directory > $null
}

foreach ($file in $files) {
    $dest_path = "$current_dir\$($file.dest)"
    if (-not (Test-Path -Path $dest_path)) {
        Invoke-WebRequest -Uri $file.url -OutFile $dest_path
    }
}

New-Process -executable "imgburn.exe" -arguments @(
    "/MODE", "BUILD",
    "/OUTPUTMODE", "IMAGEFILE",
    "/SRC", "$current_dir\iso",
    "/DEST", "$current_dir\secondary.iso",
    "/ROOTFOLDER", "YES",
    "/OVERWRITE", "YES",
    "/VOLUMELABEL", "2008-bootstrap",
    "/NOIMAGEDETAILS",
    "/START",
    "/CLOSE"
)

$mds_file = "$current_dir\secondary.mds"
if (Test-Path -Path $mds_file) {
    Remove-Item -Path $mds_file > $null
}