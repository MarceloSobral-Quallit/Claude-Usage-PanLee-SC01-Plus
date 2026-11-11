<#
.SYNOPSIS
    Cria, repara ou atualiza o ambiente ESP-IDF usado por este repositorio,
    inteiramente dentro dele (nada vai para o Python global nem para ~/.espressif).

.DESCRIPTION
    Idempotente: pode ser rodado a qualquer momento; so baixa/recria o que falta.
      1. Clona o ESP-IDF em .idf-env\esp-idf, se ausente, e o deixa no commit
         fixado em idf_common.ps1 ($IdfCommit), com os submodulos.
      2. Remove venvs Python obsoletos/quebrados (ex.: um venv cujo Python base
         foi desinstalado) e o idf-env.json com caminho antigo do repo.
      3. Roda o install.ps1 oficial com o Python 3.12 do sistema na frente do
         PATH: baixa o toolchain que faltar e recria o venv
         .idf-env\tools\python_env\idf<ver>_py3.12_env com os pacotes pip.

    Chamado automaticamente por activate-esp-idf.ps1 e build.ps1 quando o
    ambiente esta incompleto. Ver docs/REQUISITOS_COMPILACAO.md.

.EXAMPLE
    .\tools\setup_esp_idf_env.ps1
#>
param(
    [string]$Target = "esp32s3"
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot "idf_common.ps1")
$IdfRef = $IdfBranch

Write-Host "Repositorio: $RepoRoot"
Write-Host "Ambiente ESP-IDF (local, fora do git): $EnvRoot"

if (-not (Test-Path $EnvRoot)) {
    New-Item -ItemType Directory -Path $EnvRoot | Out-Null
}

if (Test-Path (Join-Path $IdfDir ".git")) {
    Write-Host "ESP-IDF ja presente em $IdfDir."
} else {
    if (Test-Path $IdfDir) {
        Write-Host "Removendo checkout incompleto do ESP-IDF: $IdfDir"
        Remove-Item -Recurse -Force $IdfDir
    }
    Write-Host "Clonando ESP-IDF ($IdfRef) em $IdfDir ..."
    git clone -b $IdfRef https://github.com/espressif/esp-idf.git $IdfDir
    if ($LASTEXITCODE -ne 0) { throw "git clone do ESP-IDF falhou (codigo $LASTEXITCODE)." }
}

# Garante o commit fixado (o clone traz a ponta da branch) e os submodulos dele.
if ((Get-IdfHead) -ne $IdfCommit) {
    Write-Host "Colocando o ESP-IDF no commit fixado $IdfCommit ..."
    git -c "safe.directory=*" -C $IdfDir fetch origin $IdfRef
    git -c "safe.directory=*" -C $IdfDir checkout --force $IdfCommit
    if ($LASTEXITCODE -ne 0) { throw "checkout do commit $IdfCommit falhou (codigo $LASTEXITCODE)." }
}
git -c "safe.directory=*" -C $IdfDir submodule update --init --recursive
if ($LASTEXITCODE -ne 0) { throw "submodule update do ESP-IDF falhou (codigo $LASTEXITCODE)." }

$pythonExe = Use-IdfPython
Write-Host "Python usado pelo ESP-IDF: $pythonExe"

Remove-StaleIdfPythonEnvs

# Redireciona toolchain/venv para dentro do repo (so neste processo).
$env:IDF_TOOLS_PATH = $ToolsDir

Write-Host "Instalando/conferindo toolchain e venv para '$Target' em $ToolsDir ..."
& (Join-Path $IdfDir "install.ps1") $Target
if ($LASTEXITCODE -ne 0) { throw "install.ps1 do ESP-IDF falhou (codigo $LASTEXITCODE)." }

if (-not (Test-IdfEnvReady)) {
    throw "Ambiente ESP-IDF continua incompleto depois do install.ps1. Veja a saida acima."
}

Write-Host ""
Write-Host "Pronto. Para compilar/gravar:"
Write-Host "  .\tools\build.ps1                 # so compila"
Write-Host "  .\tools\build.ps1 -Port COM4      # compila e grava"
