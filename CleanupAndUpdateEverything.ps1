param (
    [switch]$SilentMode
)

$ErrorActionPreference = "SilentlyContinue"
Write-Host "Iniciando processo automatizado..." -ForegroundColor Green

# --- FUNÇÕES ---
function Safe-Remove {
    param([string]$Path)
    if (Test-Path $Path) {
        $items = Get-ChildItem -Path $Path -Recurse -Force
        if ($items.Count -gt 0) {
            Remove-Item -Path $Path -Recurse -Force
            Write-Host "[OK] Limpado: $Path" -ForegroundColor Cyan
        }
    }
}

# === 1. LIMPEZAS E CACHE ===
Write-Host "`n=== 1. Limpeza de Arquivos Temporários ===" -ForegroundColor Magenta
Safe-Remove "$env:TEMP\*"
Safe-Remove "C:\Windows\Temp\*"
Safe-Remove "C:\Windows\Prefetch\*"
Safe-Remove "$env:LOCALAPPDATA\Microsoft\Windows\Explorer\thumbcache_*.db"

Write-Host "Limpando cache do Windows Update..." -ForegroundColor Cyan
Stop-Service -Name wuauserv -Force
Safe-Remove "C:\Windows\SoftwareDistribution\Download\*"
Start-Service -Name wuauserv

Write-Host "Esvaziando Lixeira..." -ForegroundColor Cyan
Clear-RecycleBin -Force

# === 2. REPARO DE SISTEMA (DISM & SFC) ===
Write-Host "`n=== 2. Reparo de Imagem e Arquivos (DISM/SFC) ===" -ForegroundColor Magenta
DISM /Online /Cleanup-Image /RestoreHealth
DISM /Online /Cleanup-Image /StartComponentCleanup /ResetBase
sfc /scannow

# === 3. REDE E CONECTIVIDADE ===
Write-Host "`n=== 3. Reset de Rede e DNS ===" -ForegroundColor Magenta
ipconfig /flushdns | Out-Null
ipconfig /release | Out-Null
ipconfig /renew | Out-Null
netsh winsock reset | Out-Null
netsh int ip reset | Out-Null
Write-Host "Rede resetada com sucesso." -ForegroundColor Green

# === 4. ATUALIZAÇÕES (Winget & Windows) ===
Write-Host "`n=== 4. Atualizacoes Silenciosas ===" -ForegroundColor Magenta
winget upgrade --all --silent --accept-package-agreements --accept-source-agreements

if (Get-Module -ListAvailable -Name PSWindowsUpdate) {
    Import-Module PSWindowsUpdate
    Get-WindowsUpdate -AcceptAll -Install -AutoReboot:$false
} else {
    usoclient StartScan
    usoclient StartDownload
    usoclient StartInstall
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

$checkDisk = Read-Host "Deseja agendar CHKDSK para o próximo boot? (S/N)"
if ($checkDisk -eq "S") { echo y | chkdsk C: /f /r }

$openStore = Read-Host "Deseja abrir a Microsoft Store? (S/N)"
if ($openStore -eq "S") { Start-Process "ms-windows-store://downloadsandupdates" }

$RebootPending = Test-Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending"
if ($RebootPending) {
    Write-Host "`n[!] REBOOT NECESSÁRIO!" -ForegroundColor Red
    $rebootChoice = Read-Host "Reiniciar agora? (S/N)"
    if ($rebootChoice -eq "S") { Restart-Computer -Force }
}

Write-Host "`nProcesso finalizado."