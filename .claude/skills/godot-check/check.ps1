# Verificación headless de Futbolista Deckbuilder.
# Uso (desde la raíz del repo): & .\.claude\skills\godot-check\check.ps1 [-Matches 5] [-Balance] [-SkipSmoke]
# Godot se busca en: variable de entorno GODOT, la carpeta que contiene el repo, y el PATH.
param(
    [int]$Matches = 5,
    [switch]$Balance,
    [switch]$SkipSmoke,
    [int]$TimeoutSec = 240,
    [int]$BalanceTimeoutSec = 600   # sim.gd juega miles de partidos con el planificador de CoachBot
)

$project = (Resolve-Path (Join-Path $PSScriptRoot "..\..\..")).Path
$logDir = Join-Path $env:TEMP "godot-check"
New-Item -ItemType Directory -Force $logDir | Out-Null

$godot = $env:GODOT
if (-not $godot -or -not (Test-Path $godot)) {
    $godot = Get-ChildItem (Split-Path $project -Parent) -Filter "Godot_v4*_console.exe" -ErrorAction SilentlyContinue |
        Sort-Object Name -Descending | Select-Object -First 1 -ExpandProperty FullName
}
if (-not $godot) {
    $godot = (Get-Command "godot*" -ErrorAction SilentlyContinue | Select-Object -First 1).Source
}
if (-not $godot) {
    Write-Output "FALTA Godot: define `$env:GODOT con la ruta al ejecutable *_console.exe"
    exit 2
}

# Ejecuta Godot con tiempo límite. Devuelve el código de salida (124 = tiempo agotado).
function Invoke-Godot([string]$name, [string[]]$godotArgs, [int]$timeout = $TimeoutSec) {
    $out = Join-Path $logDir "$name.out.txt"
    $err = Join-Path $logDir "$name.err.txt"
    $argList = @("--headless", "--path", "`"$project`"") + $godotArgs
    $p = Start-Process $godot -ArgumentList $argList -RedirectStandardOutput $out -RedirectStandardError $err -PassThru -NoNewWindow
    $null = $p.Handle   # sin esto ExitCode queda vacío al terminar
    if (-not $p.WaitForExit($timeout * 1000)) {
        $p.Kill()
        Write-Host "[$name] TIEMPO AGOTADO tras $timeout s"
        return 124
    }
    $p.WaitForExit()
    # Un error de script en ejecución no cambia el código de salida de Godot: se cuenta aparte.
    if ($name -ne "import" -and (Select-String -Path $err -Pattern "SCRIPT ERROR" -Quiet)) {
        Write-Host "[$name] Hubo errores de script en ejecución (ver $err)"
        Get-Content $err | Where-Object { $_ -match 'SCRIPT ERROR|at: ' } | Select-Object -First 10 | ForEach-Object { Write-Host "[$name] $_" }
        return 3
    }
    if ($name -ne "import") {   # la salida del import es solo progreso del editor
        Get-Content $out | Where-Object { $_ -and $_ -notmatch '^Godot Engine v' } | ForEach-Object { Write-Host "[$name] $_" }
    }
    Get-Content $err | Where-Object { $_ -match 'ERROR|WARNING|at: ' } | Select-Object -First 30 | ForEach-Object { Write-Host "[$name] $_" }
    return $p.ExitCode
}

$failed = @()

# 1. Importar (regenera la caché de class_name tras crear o renombrar scripts)
$code = Invoke-Godot "import" @("--import")
$scriptErrors = Select-String -Path (Join-Path $logDir "import.err.txt") -Pattern "SCRIPT ERROR|Parse Error" -ErrorAction SilentlyContinue
if ($scriptErrors) { $failed += "import" }

# 2. Compilar todos los scripts y escenas
$code = Invoke-Godot "check_scripts" @("-s", "res://tests/check_scripts.gd")
if ($code -ne 0) { $failed += "check_scripts" }

# 3. Reglas del motor y de los datos (rápido, sin escenas)
if ($failed.Count -eq 0) {
    $code = Invoke-Godot "engine_rules" @("-s", "res://tests/engine_rules.gd")
    if ($code -ne 0) { $failed += "engine_rules" }
    $code = Invoke-Godot "career_rules" @("-s", "res://tests/career_rules.gd")
    if ($code -ne 0) { $failed += "career_rules" }
    $code = Invoke-Godot "data_rules" @("-s", "res://tests/data_rules.gd")
    if ($code -ne 0) { $failed += "data_rules" }
}

# 4. Prueba de humo del partido (solo si compila)
if (-not $SkipSmoke -and $failed.Count -eq 0) {
    $code = Invoke-Godot "smoke_match" @("-s", "res://tests/smoke_match.gd", "--", "--matches=$Matches")
    if ($code -ne 0) { $failed += "smoke_match" }
    $code = Invoke-Godot "smoke_career" @("-s", "res://tests/smoke_career.gd")
    if ($code -ne 0) { $failed += "smoke_career" }
}

# 5. Métricas de balance por arquetipo (opcional, 2000 partidos por perfil con semillas fijas)
if ($Balance -and $failed.Count -eq 0) {
    $code = Invoke-Godot "balance" @("-s", "res://core/sim.gd") $BalanceTimeoutSec
    if ($code -ne 0) { $failed += "balance" }
}

Write-Output ""
Write-Output "Logs completos: $logDir"
if ($failed.Count -gt 0) {
    Write-Output "RESULTADO: FALLA ($($failed -join ', '))"
    exit 1
}
Write-Output "RESULTADO: OK"
exit 0
