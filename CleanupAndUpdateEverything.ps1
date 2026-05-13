param (
    [switch]$SilentMode
)

Write-Host "Iniciando processo automatizado..." -ForegroundColor Green

# --- FUNÇÕES ---
function Confirm-Action {
    param(
        [string]$Prompt,
        [scriptblock]$Action
    )
    $choice = Read-Host $Prompt
    if ($choice -eq "S") {
        & $Action
    }
}

function Safe-Remove {
    param([string]$Path)
    Remove-Item -Path $Path -Recurse -Force -ErrorAction SilentlyContinue
    if ($?) {
        Write-Host "[OK] Limpado: $Path" -ForegroundColor Cyan
    }
}

# === 1. LIMPEZAS E CACHE ===
Write-Host "`n=== 1. Limpeza de Arquivos Temporários ===" -ForegroundColor Magenta
Safe-Remove "$env:TEMP\*"
Safe-Remove "$env:windir\Temp\*"
Safe-Remove "$env:windir\Prefetch\*"
Safe-Remove "$env:LOCALAPPDATA\Microsoft\Windows\Explorer\thumbcache_*.db"

Write-Host "Limpando cache do Windows Update..." -ForegroundColor Cyan
Stop-Service -Name wuauserv -Force
Safe-Remove "$env:windir\SoftwareDistribution\Download\*"
Start-Service -Name wuauserv

Write-Host "Esvaziando Lixeira..." -ForegroundColor Cyan
Clear-RecycleBin -Force

# === 2. REPARO DE SISTEMA (DISM & SFC) ===
Write-Host "`n=== 2. Reparo de Imagem e Arquivos (DISM/SFC) ===" -ForegroundColor Magenta
& "$env:windir\System32\dism.exe" /Online /Cleanup-Image /RestoreHealth
& "$env:windir\System32\dism.exe" /Online /Cleanup-Image /StartComponentCleanup /ResetBase
& "$env:windir\System32\sfc.exe" /scannow

# === 3. REDE E CONECTIVIDADE ===
Write-Host "`n=== 3. Reset de Rede e DNS ===" -ForegroundColor Magenta
& {
    & "$env:windir\System32\ipconfig.exe" /flushdns
    & "$env:windir\System32\ipconfig.exe" /release
    & "$env:windir\System32\ipconfig.exe" /renew
    & "$env:windir\System32\netsh.exe" winsock reset
    & "$env:windir\System32\netsh.exe" int ip reset
} | Out-Null
Write-Host "Rede resetada com sucesso." -ForegroundColor Green

# === 4. ATUALIZAÇÕES (Winget & Windows) ===
Write-Host "`n=== 4. Atualizacoes Silenciosas ===" -ForegroundColor Magenta
& "$env:LOCALAPPDATA\Microsoft\WindowsApps\winget.exe" upgrade --all --silent --accept-package-agreements --accept-source-agreements

if (Get-Module -ListAvailable -Name PSWindowsUpdate) {
    Import-Module PSWindowsUpdate
    Get-WindowsUpdate -AcceptAll -Install -AutoReboot:$false
} else {
    & "$env:windir\System32\usoclient.exe" StartScan
    & "$env:windir\System32\usoclient.exe" StartDownload
    & "$env:windir\System32\usoclient.exe" StartInstall
}

# === 5. OTIMIZAÇÃO DE DISCO (SSD/HDD) ===
Write-Host "`n=== 5. Otimizacao de Volume ===" -ForegroundColor Magenta
Optimize-Volume -DriveLetter C -ReTrim -Defrag

# ============================================================
# === SEÇÃO DE CONFIRMAÇÕES (POR ÚLTIMO) ===
# ============================================================
if ($SilentMode) {
    Write-Host "`n[!] Modo Silencioso Ativo. Finalizando sem perguntas." -ForegroundColor Yellow
    exit
}

Write-Host "`n" + "="*60 -ForegroundColor Yellow
Write-Host "MANUTENÇÃO CONCLUÍDA. REVISÃO DE AÇÕES PENDENTES:" -ForegroundColor Yellow
Write-Host "="*60 -ForegroundColor Yellow

Confirm-Action -Prompt "Deseja agendar CHKDSK para o próximo boot? (S/N)" -Action { Write-Output y | & "$env:windir\System32\chkdsk.exe" C: /f /r }


Confirm-Action -Prompt "Deseja abrir a Microsoft Store? (S/N)" -Action { Start-Process "ms-windows-store://downloadsandupdates" }


$RebootPending = Test-Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending"
if ($RebootPending) {
    Write-Host "`n[!] REBOOT NECESSÁRIO!" -ForegroundColor Red
    Confirm-Action -Prompt "Reiniciar agora? (S/N)" -Action { Restart-Computer -Force }

}

Write-Host "`nProcesso finalizado."
