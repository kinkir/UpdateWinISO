param(
    [Parameter(Mandatory=$true)]
    [string]$installMountDir,
    
    [string]$AppxRemove = "yes",
    [string]$CapabilitiesRemove = "yes",
    [string]$OnedriveRemove = "yes",
    [string]$EDGERemove = "no",
    [string]$AIRemove = "yes",
    [string]$TweaksApply = "yes"
)

[console]::OutputEncoding = [System.Text.Encoding]::UTF8

$scriptPath = Split-Path -Parent -Path $MyInvocation.MyCommand.Definition
$logFile = Join-Path -Path $scriptPath -ChildPath "debloat_core.log"

Function Write-Log {
    Param([string]$msg)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Add-Content -Path $logFile -Value "[$timestamp] $msg"
}

Write-Host "========================================" -ForegroundColor Cyan
Write-Host " 开始执行离线映像精简 (Debloat Core)" -ForegroundColor Cyan
Write-Host " 目标挂载目录: $installMountDir" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Log "Starting Debloat process on $installMountDir"

# ==========================================
# 1. 移除内置 Appx 预装应用
# ==========================================
if ($AppxRemove -eq "yes") {
    Write-Host "`nRemoving Appx packages..." -ForegroundColor Yellow
    $appsToRemove = @(
        "Clipchamp.Clipchamp",
        "Microsoft.BingSearch",
        "Microsoft.BingNews",
        "Microsoft.BingWeather",
        "Microsoft.GamingApp",
        "Microsoft.GetHelp",
        "Microsoft.Getstarted",
        "Microsoft.MicrosoftOfficeHub",
        "Microsoft.MicrosoftSolitaireCollection",
        "Microsoft.People",
        "Microsoft.PowerAutomateDesktop",
        "Microsoft.Todos",
        "Microsoft.WindowsAlarms",
        "Microsoft.WindowsCamera",
        "microsoft.windowscommunicationsapps",
        "Microsoft.WindowsFeedbackHub",
        "Microsoft.WindowsMaps",
        "Microsoft.WindowsSoundRecorder",
        "Microsoft.Xbox.TCUI",
        "Microsoft.XboxApp",
        "Microsoft.XboxGameOverlay",
        "Microsoft.XboxGamingOverlay",
        "Microsoft.XboxIdentityProvider",
        "Microsoft.XboxSpeechToTextOverlay",
        "Microsoft.YourPhone",
        "Microsoft.ZuneMusic",
        "Microsoft.ZuneVideo",
        "MicrosoftCorporationII.MicrosoftFamily",
        "MicrosoftCorporationII.QuickAssist",
        "Microsoft.549981C3F5F10"
    )

    foreach ($app in $appsToRemove) {
        Write-Host "Removing $app... " -NoNewline
        try {
            Remove-AppxProvisionedPackage -Path $installMountDir -PackageName $app -ErrorAction SilentlyContinue | Out-Null
            Write-Host "Done" -ForegroundColor Green
        } catch {
            Write-Host "Failed/Not Found" -ForegroundColor DarkGray
        }
    }
}

# ==========================================
# 2. 移除 Windows 可选功能
# ==========================================
if ($CapabilitiesRemove -eq "yes") {
    Write-Host "`nRemoving Capabilities..." -ForegroundColor Yellow
    $capabilitiesToRemove = @(
        "App.StepsRecorder~~~~0.0.1.0",
        "App.Support.QuickAssist~~~~0.0.1.0",
        "Browser.InternetExplorer~~~~0.0.11.0",
        "MathRecognizer~~~~0.0.1.0",
        "Media.WindowsMediaPlayer~~~~0.0.12.0",
        "Microsoft.Windows.Notepad.System~~~~0.0.1.0",
        "Microsoft.Windows.WordPad~~~~0.0.1.0",
        "Print.Management.Console~~~~0.0.1.0"
    )

    foreach ($capability in $capabilitiesToRemove) {
        Write-Host "Removing $capability... " -NoNewline
        try {
            Remove-WindowsCapability -Path $installMountDir -Name $capability -ErrorAction SilentlyContinue | Out-Null
            Write-Host "Done" -ForegroundColor Green
        } catch {
            Write-Host "Failed/Not Found" -ForegroundColor DarkGray
        }
    }
}

# ==========================================
# 3. 移除 OneDrive
# ==========================================
if ($OnedriveRemove -eq "yes") {
    Write-Host "`nRemoving OneDrive..." -ForegroundColor Yellow
    try {
        & reg.exe load "HKLM\OFFLINE_DEFAULT" "$installMountDir\Windows\System32\config\DEFAULT" | Out-Null
        & reg.exe delete "HKLM\OFFLINE_DEFAULT\Software\Microsoft\Windows\CurrentVersion\Run" /v "OneDriveSetup" /f 2>$null | Out-Null
        [gc]::Collect(); [gc]::WaitForPendingFinalizers()
        & reg.exe unload "HKLM\OFFLINE_DEFAULT" | Out-Null
        
        Remove-Item -Path "$installMountDir\Windows\SysWOW64\OneDriveSetup.exe" -Force -ErrorAction SilentlyContinue
        Remove-Item -Path "$installMountDir\Windows\System32\OneDriveSetup.exe" -Force -ErrorAction SilentlyContinue
        Write-Host "OneDrive removed successfully." -ForegroundColor Green
    } catch {}
}

# ==========================================
# 4. 移除 Edge 浏览器
# ==========================================
if ($EDGERemove -eq "yes") {
    Write-Host "`nRemoving Edge..." -ForegroundColor Yellow
    try {
        & reg.exe load "HKLM\OFFLINE_SOFTWARE" "$installMountDir\Windows\System32\config\SOFTWARE" | Out-Null
        & reg.exe add "HKLM\OFFLINE_SOFTWARE\Microsoft\EdgeUpdate" /v "DoNotUpdateToEdgeWithChromium" /t REG_DWORD /d 1 /f | Out-Null
        [gc]::Collect(); [gc]::WaitForPendingFinalizers()
        & reg.exe unload "HKLM\OFFLINE_SOFTWARE" | Out-Null

        $edgePaths = @(
            "$installMountDir\Program Files (x86)\Microsoft\Edge",
            "$installMountDir\Program Files (x86)\Microsoft\EdgeCore",
            "$installMountDir\Program Files (x86)\Microsoft\EdgeUpdate",
            "$installMountDir\Program Files (x86)\Microsoft\EdgeWebView"
        )
        foreach ($path in $edgePaths) {
            if (Test-Path $path) { Remove-Item -Path $path -Recurse -Force -ErrorAction SilentlyContinue }
        }
        Write-Host "Edge removed successfully." -ForegroundColor Green
    } catch {}
}

# ==========================================
# 5. 移除 AI / Copilot / Recall
# ==========================================
if ($AIRemove -eq "yes") {
    Write-Host "`nRemoving AI/Copilot/Recall..." -ForegroundColor Yellow
    try {
        & reg.exe load "HKLM\OFFLINE_SOFTWARE" "$installMountDir\Windows\System32\config\SOFTWARE" | Out-Null
        & reg.exe add "HKLM\OFFLINE_SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot" /v "TurnOffWindowsCopilot" /t REG_DWORD /d 1 /f | Out-Null
        & reg.exe add "HKLM\OFFLINE_SOFTWARE\Policies\Microsoft\Windows\WindowsAI" /v "DisableAIDataAnalysis" /t REG_DWORD /d 1 /f | Out-Null
        [gc]::Collect(); [gc]::WaitForPendingFinalizers()
        & reg.exe unload "HKLM\OFFLINE_SOFTWARE" | Out-Null

        $aiPaths = @(
            "$installMountDir\Windows\SystemApps\Microsoft.Windows.Ai.Copilot.Provider*",
            "$installMountDir\Program Files\WindowsAI"
        )
        foreach ($path in $aiPaths) {
            if (Test-Path $path) { Remove-Item -Path $path -Recurse -Force -ErrorAction SilentlyContinue }
        }
        Write-Host "AI features removed successfully." -ForegroundColor Green
    } catch {}
}

# ==========================================
# 6. 系统优化 (Registry Tweaks)
# ==========================================
if ($TweaksApply -eq "yes") {
    Write-Host "`nApplying Registry Tweaks..." -ForegroundColor Yellow
    try {
        & reg.exe load "HKLM\OFFLINE_SYSTEM" "$installMountDir\Windows\System32\config\SYSTEM" | Out-Null
        & reg.exe load "HKLM\OFFLINE_SOFTWARE" "$installMountDir\Windows\System32\config\SOFTWARE" | Out-Null
        & reg.exe load "HKLM\OFFLINE_DEFAULT" "$installMountDir\Windows\System32\config\DEFAULT" | Out-Null
        & reg.exe load "HKLM\OFFLINE_NTUSER" "$installMountDir\Users\Default\NTUSER.DAT" | Out-Null

        # Bypasses
        & reg.exe add "HKLM\OFFLINE_SYSTEM\Setup\LabConfig" /v "BypassTPMCheck" /t REG_DWORD /d 1 /f | Out-Null
        & reg.exe add "HKLM\OFFLINE_SYSTEM\Setup\LabConfig" /v "BypassSecureBootCheck" /t REG_DWORD /d 1 /f | Out-Null
        & reg.exe add "HKLM\OFFLINE_SYSTEM\Setup\LabConfig" /v "BypassRAMCheck" /t REG_DWORD /d 1 /f | Out-Null
        & reg.exe add "HKLM\OFFLINE_SYSTEM\Setup\LabConfig" /v "BypassCPUCheck" /t REG_DWORD /d 1 /f | Out-Null
        & reg.exe add "HKLM\OFFLINE_SYSTEM\Setup\LabConfig" /v "BypassStorageCheck" /t REG_DWORD /d 1 /f | Out-Null
        & reg.exe add "HKLM\OFFLINE_SYSTEM\Setup\MoSetup" /v "AllowUpgradesWithUnsupportedTPMOrCPU" /t REG_DWORD /d 1 /f | Out-Null

        # Telemetry
        & reg.exe add "HKLM\OFFLINE_SOFTWARE\Policies\Microsoft\Windows\DataCollection" /v "AllowTelemetry" /t REG_DWORD /d 0 /f | Out-Null
        & reg.exe add "HKLM\OFFLINE_SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection" /v "AllowTelemetry" /t REG_DWORD /d 0 /f | Out-Null

        # Start Menu & Ads
        & reg.exe add "HKLM\OFFLINE_NTUSER\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v "SystemPaneSuggestionsEnabled" /t REG_DWORD /d 0 /f | Out-Null
        & reg.exe add "HKLM\OFFLINE_NTUSER\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v "SilentInstalledAppsEnabled" /t REG_DWORD /d 0 /f | Out-Null
        & reg.exe add "HKLM\OFFLINE_SOFTWARE\Policies\Microsoft\Windows\CloudContent" /v "DisableWindowsConsumerFeatures" /t REG_DWORD /d 1 /f | Out-Null

        # BitLocker
        & reg.exe add "HKLM\OFFLINE_SYSTEM\CurrentControlSet\Control\BitLocker" /v "PreventDeviceEncryption" /t REG_DWORD /d 1 /f | Out-Null

        # Network
        & reg.exe add "HKLM\OFFLINE_SOFTWARE\Microsoft\Windows\CurrentVersion\DeliveryOptimization\Config" /v "DODownloadMode" /t REG_DWORD /d 0 /f | Out-Null

        # Mouse
        & reg.exe add "HKLM\OFFLINE_DEFAULT\Control Panel\Mouse" /v "MouseSpeed" /t REG_SZ /d "0" /f | Out-Null
        & reg.exe add "HKLM\OFFLINE_NTUSER\Control Panel\Mouse" /v "MouseSpeed" /t REG_SZ /d "0" /f | Out-Null

        [gc]::Collect(); [gc]::WaitForPendingFinalizers()

        & reg.exe unload "HKLM\OFFLINE_SYSTEM" | Out-Null
        & reg.exe unload "HKLM\OFFLINE_SOFTWARE" | Out-Null
        & reg.exe unload "HKLM\OFFLINE_DEFAULT" | Out-Null
        & reg.exe unload "HKLM\OFFLINE_NTUSER" | Out-Null

        Write-Host "Registry Tweaks applied successfully." -ForegroundColor Green
    } catch {}
}

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host " Debloat Core 脚本执行完毕，将控制权交还 W10UI" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan
