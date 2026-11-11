<#
.SYNOPSIS
    Ativa, na sessao ATUAL do PowerShell, o ambiente ESP-IDF local deste repo.

.DESCRIPTION
    Precisa ser executado com "dot-sourcing" (o ponto no inicio), senao as
    variaveis de ambiente (PATH, IDF_PATH, IDF_TOOLS_PATH) somem ao terminar:

        . .\tools\activate-esp-idf.ps1

    Se o ambiente estiver incompleto ou quebrado (ESP-IDF ausente, toolchain
    faltando, venv Python inexistente ou apontando para um Python removido),
    roda setup_esp_idf_env.ps1 antes, que baixa/recria o necessario.
    Nao altera nada fora desta sessao do PowerShell nem fora deste repositorio.
#>

. (Join-Path $PSScriptRoot "idf_common.ps1")

if (-not (Test-IdfEnvReady)) {
    Write-Host "Ambiente ESP-IDF incompleto ou quebrado; rodando setup_esp_idf_env.ps1 ..."
    & (Join-Path $PSScriptRoot "setup_esp_idf_env.ps1")
    if (-not (Test-IdfEnvReady)) {
        Write-Error "Ambiente ESP-IDF continua incompleto. Veja a saida do setup acima."
        return
    }
}

$null = Use-IdfPython
$env:IDF_TOOLS_PATH = $ToolsDir
. (Join-Path $IdfDir "export.ps1")
