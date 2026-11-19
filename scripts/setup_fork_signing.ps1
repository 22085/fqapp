# Run once on your own Windows computer with GitHub CLI and a JDK installed.
# The keystore stays on this computer. Keep a backup: losing it prevents updates.
$ErrorActionPreference = 'Stop'
$repo = 'Ethan13322836698/fqapp'
Get-Command gh, keytool -ErrorAction Stop | Out-Null
& gh auth status
if ($LASTEXITCODE -ne 0) { throw 'Run gh auth login first.' }
$folder = Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'fqapp-signing'
New-Item -ItemType Directory -Force $folder | Out-Null
$key = Join-Path $folder 'fqapp-ethan.jks'
$passFile = Join-Path $folder 'keystore-password.txt'
if (!(Test-Path $key)) {
    if (Test-Path $passFile) { throw 'Password backup already exists. Check your signing backup before creating another key.' }
    $random = New-Object byte[] 32
    $rng = [Security.Cryptography.RandomNumberGenerator]::Create()
    $rng.GetBytes($random)
    $rng.Dispose()
    $password = [Convert]::ToBase64String($random)
    # Save before generation so interruption never leaves a key without its password.
    [IO.File]::WriteAllText($passFile, $password)
    $env:FQAPP_SIGNING_PASSWORD = $password
    & keytool -genkeypair -storetype JKS -keystore $key -alias fqapp-fork -storepass:env FQAPP_SIGNING_PASSWORD -keypass:env FQAPP_SIGNING_PASSWORD -keyalg RSA -keysize 3072 -validity 10000 -dname 'CN=FQApp Ethan'
    if ($LASTEXITCODE -ne 0) { throw 'Keystore generation failed.' }
}
if (!(Test-Path $passFile)) { throw 'Restore the password backup before continuing. Do not replace the keystore.' }
$password = [IO.File]::ReadAllText($passFile).Trim()
$env:FQAPP_SIGNING_PASSWORD = $password
$cert = Join-Path $folder 'certificate.der'
try {
    & keytool -exportcert -keystore $key -alias fqapp-fork -storepass:env FQAPP_SIGNING_PASSWORD -file $cert
    if ($LASTEXITCODE -ne 0) { throw 'Cannot read the signing certificate.' }
    $values = @{
        RELEASE_KEYSTORE_BASE64 = [Convert]::ToBase64String([IO.File]::ReadAllBytes($key))
        RELEASE_STORE_PASSWORD = $password
        RELEASE_KEY_PASSWORD = $password
        RELEASE_KEY_ALIAS = 'fqapp-fork'
    }
    foreach ($name in $values.Keys) {
        # Write exact bytes without PowerShell's pipeline newline. Passwords
        # stay out of process arguments and temporary files.
        $start = New-Object System.Diagnostics.ProcessStartInfo
        $start.FileName = (Get-Command gh).Source
        $start.Arguments = "secret set $name --repo $repo"
        $start.UseShellExecute = $false
        $start.RedirectStandardInput = $true
        $process = [System.Diagnostics.Process]::Start($start)
        $process.StandardInput.Write($values[$name])
        $process.StandardInput.Close()
        $process.WaitForExit()
        $result = $process.ExitCode
        $process.Dispose()
        if ($result -ne 0) { throw "Failed to save $name. Run this script again with the same keystore." }
    }
    $hash = (Get-FileHash -Algorithm SHA256 $cert).Hash.ToLowerInvariant()
    & gh variable set FORK_RELEASE_SIGNER_SHA256 --body $hash --repo $repo
    if ($LASTEXITCODE -ne 0) { throw 'Failed to save certificate fingerprint.' }
    Write-Host "Ready. Run the Android workflow on master. Back up $folder securely. Never commit this folder."
} finally {
    Remove-Item Env:FQAPP_SIGNING_PASSWORD -ErrorAction SilentlyContinue
}
