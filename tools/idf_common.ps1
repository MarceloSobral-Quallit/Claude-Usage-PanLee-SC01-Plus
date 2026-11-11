<#
.SYNOPSIS
    Funcoes comuns aos scripts do ambiente ESP-IDF local (setup/activate/build).
    Carregar com dot-sourcing:  . (Join-Path $PSScriptRoot "idf_common.ps1")

.DESCRIPTION
    - Versao de Python suportada FIXA em 3.12 (o Python do sistema, instalado
      para todos os usuarios). Nao ha mais referencia a 3.13.
    - O venv do ESP-IDF fica em .idf-env\tools\python_env\idf<ver>_py3.12_env.
    - Venvs cujo Python base nao existe mais (ex.: o antigo py3.13) ou de outra
      versao sao considerados obsoletos e removidos pelo setup.
    Compativel com Windows PowerShell 5.1 e PowerShell 7 (somente ASCII).
#>

$IdfPythonVersion = "3.12"

# Commit exato do ESP-IDF que gerou as releases aprovadas (v5.5.5-316-g1a1a5aa6513,
# branch release/v5.5). Recriar o ambiente sempre neste commit garante o mesmo
# binario; a ponta da branch muda com o tempo.
$IdfBranch = "release/v5.5"
$IdfCommit = "1a1a5aa6513592623d6b841ab8c9f3ef61eb9dfd"

$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$EnvRoot = Join-Path $RepoRoot ".idf-env"
$IdfDir = Join-Path $EnvRoot "esp-idf"
$ToolsDir = Join-Path $EnvRoot "tools"
$FirmwareDir = Join-Path $RepoRoot "firmware\panlee_sc01_plus"

function Get-IdfPython {
    # Retorna o caminho do python.exe da versao suportada, ou $null.
    $pyLauncher = Get-Command py.exe -ErrorAction SilentlyContinue
    if ($pyLauncher) {
        $saida = & $pyLauncher.Source "-$IdfPythonVersion" -c "import sys; print(sys.executable)" 2>$null
        if ($LASTEXITCODE -eq 0 -and $saida -and (Test-Path ($saida | Select-Object -Last 1))) {
            return ($saida | Select-Object -Last 1).Trim()
        }
    }
    $semPonto = $IdfPythonVersion.Replace(".", "")
    $candidatos = @(
        (Join-Path $env:ProgramFiles "Python$semPonto\python.exe"),
        (Join-Path $env:LOCALAPPDATA "Programs\Python\Python$semPonto\python.exe")
    )
    foreach ($caminho in $candidatos) {
        if (Test-Path $caminho) { return $caminho }
    }
    return $null
}

function Use-IdfPython {
    # Coloca o Python suportado na frente do PATH deste processo (o install.ps1
    # e o export.ps1 do ESP-IDF escolhem o venv pela versao do "python" do PATH).
    $pythonExe = Get-IdfPython
    if (-not $pythonExe) {
        throw "Python $IdfPythonVersion nao encontrado. Instale o Python $IdfPythonVersion para todos os usuarios (C:\Program Files\Python$($IdfPythonVersion.Replace('.', '')))."
    }
    $pythonDir = Split-Path $pythonExe -Parent
    $env:PATH = "$pythonDir;$(Join-Path $pythonDir 'Scripts');$env:PATH"
    return $pythonExe
}

function Get-IdfPythonEnvs {
    $pastaVenvs = Join-Path $ToolsDir "python_env"
    if (-not (Test-Path $pastaVenvs)) { return @() }
    return @(Get-ChildItem $pastaVenvs -Directory)
}

function Test-IdfPythonEnvHealthy {
    param([System.IO.DirectoryInfo]$Venv)
    # Saudavel = da versao suportada, criado NESTE caminho, e o Python base
    # ainda existe e executa.
    if ($Venv.Name -notlike "idf*_py$($IdfPythonVersion)_env") { return $false }
    $venvPython = Join-Path $Venv.FullName "Scripts\python.exe"
    if (-not (Test-Path $venvPython)) { return $false }
    # Venv criado em outro caminho (repo movido): os .exe de Scripts\ (pip,
    # esptool...) guardam o caminho antigo, entao precisa ser recriado.
    $cfg = Join-Path $Venv.FullName "pyvenv.cfg"
    if (Test-Path $cfg) {
        $linhaComando = Select-String -Path $cfg -Pattern '^command\s*=\s*(.*)$' | Select-Object -First 1
        if ($linhaComando) {
            $comando = $linhaComando.Matches[0].Groups[1].Value
            if ($comando.IndexOf($Venv.FullName, [System.StringComparison]::OrdinalIgnoreCase) -lt 0) { return $false }
        }
    }
    & $venvPython -c "import sys" 2>$null
    return ($LASTEXITCODE -eq 0)
}

function Remove-StaleIdfPythonEnvs {
    foreach ($venv in Get-IdfPythonEnvs) {
        if (-not (Test-IdfPythonEnvHealthy -Venv $venv)) {
            Write-Host "Removendo venv obsoleto/quebrado: $($venv.FullName)"
            Remove-Item -Recurse -Force $venv.FullName
        }
    }
    # idf-env.json guarda o caminho absoluto do checkout; se o repo mudou de
    # lugar, o arquivo fica apontando para a pasta antiga. O install.ps1 o recria.
    $idfEnvJson = Join-Path $ToolsDir "idf-env.json"
    if (Test-Path $idfEnvJson) {
        $conteudo = Get-Content $idfEnvJson -Raw
        if ($conteudo -notlike "*$($IdfDir.Replace('\', '\\'))*") {
            Write-Host "Removendo idf-env.json com caminho antigo: $idfEnvJson"
            Remove-Item -Force $idfEnvJson
        }
    }
}

function Get-IdfHead {
    if (-not (Test-Path (Join-Path $IdfDir ".git"))) { return "" }
    $cabeca = & git -c "safe.directory=*" -C $IdfDir rev-parse HEAD 2>$null
    if ($LASTEXITCODE -ne 0 -or -not $cabeca) { return "" }
    return ($cabeca | Select-Object -First 1).Trim()
}

function Test-IdfEnvReady {
    if (-not (Test-Path (Join-Path $IdfDir "export.ps1"))) { return $false }
    if ((Get-IdfHead) -ne $IdfCommit) { return $false }
    $saudaveis = @(Get-IdfPythonEnvs | Where-Object { Test-IdfPythonEnvHealthy -Venv $_ })
    if ($saudaveis.Count -eq 0) { return $false }
    if (-not (Test-Path (Join-Path $ToolsDir "tools\xtensa-esp-elf"))) { return $false }
    if (-not (Test-Path (Join-Path $ToolsDir "idf-env.json"))) { return $false }
    return $true
}
