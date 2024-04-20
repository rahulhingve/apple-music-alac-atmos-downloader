# Check if the script is running with administrative privileges
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass


$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    # Restart the script with administrative privileges
    Start-Process powershell.exe -Verb RunAs -ArgumentList ("-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"")
    Exit
}

# Set the path to the Android SDK emulator
$emulatorPath = "$env:LOCALAPPDATA\Android\Sdk\emulator\emulator.exe"

# Set the name of the AVD (Android Virtual Device)
$avdName = "Pixel_4a_API_30"

# Start the emulator in a separate PowerShell instance
$emulatorProcess = Start-Process powershell.exe -ArgumentList "-Command `"& {$emulatorPath -avd $avdName}`"" -PassThru

# Wait for the emulator to be fully connected
$emulatorConnected = $false
$timeout = 300 # 5 minutes
$startTime = Get-Date
while (-not $emulatorConnected -and ((Get-Date) - $startTime).TotalSeconds -lt $timeout) {
    if (adb.exe devices | Select-String -Pattern "emulator-5554") {
        $emulatorConnected = $true
        Write-Host "Emulator is connected."
    }
    else {
        Start-Sleep -Seconds 10
    }
}

if (-not $emulatorConnected) {
    Write-Host "Emulator did not connect within the timeout period."
    $emulatorProcess.Kill()
    Exit
}


# Change the current directory to the extracted folder
Set-Location -Path "C:\Users\Administrator\Desktop\Apple\apple-music-alac-atmos-downloader-main"

# Create a batch script file for Android shell commands
$batchScriptPath = "android_shell_commands.sh"

@"
#!/bin/bash
cd /data/local/tmp/
chmod 777 frida
./frida-server
"@ | Out-File -FilePath $batchScriptPath -Encoding ASCII

# Run Android shell commands in a separate PowerShell instance
$shellProcess = Start-Process cmd.exe -ArgumentList "/C adb root & adb forward tcp:10020 tcp:10020 & adb shell < $batchScriptPath" -NoNewWindow -PassThru

# Open Command Prompt window 1 in the extracted folder
$cmdWindow1Args = "/C cd `"\apple-music-alac-atmos-downloader-main`" & frida -U -l agent.js -f com.apple.android.music & pause"
Start-Process cmd.exe -ArgumentList $cmdWindow1Args

# Open Command Prompt window 2 in the extracted folder
$cmdWindow2Args = "/K cd `"\apple-music-alac-atmos-downloader-main`""
Start-Process cmd.exe -ArgumentList $cmdWindow2Args

# Wait for the background process to complete
$shellProcess.WaitForExit()

# Clean up the batch script file
Remove-Item $batchScriptPath

# Close all open Command Prompt windows
Get-Process cmd -ErrorAction SilentlyContinue | ForEach-Object { $_.CloseMainWindow() | Out-Null }
