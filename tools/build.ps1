<#
.SYNOPSIS
    Compila (e opcionalmente grava) o firmware, recriando o que for necessario,
    com opcao de limpar artefatos de build, temporarios e o ambiente.

.DESCRIPTION
    0. -Limpar (opcional, antes de tudo), niveis separados por virgula:
         build    - firmware\...\build, managed_components, sdkconfig.old
                    (regenerados pelo proximo build; dependencies.lock e
                    versionado e nao e apagado)
         temp     - __pycache__, *.pyc, *.tmp e *.log fora de releases\ e .git
         ambiente - .idf-env\ inteiro (ESP-IDF + toolchain + venv; recriado
                    sozinho no proximo build, no commit fixado do ESP-IDF)
         tudo     - os tres acima
       Com -SomenteLimpar, limpa e sai sem compilar.
       O sdkconfig local NAO e apagado (guarda a configuracao em uso).
    1. Ativa o ambiente ESP-IDF local (activate-esp-idf.ps1), que roda o setup
       sozinho se faltar ESP-IDF/toolchain/venv ou se estiverem quebrados.
    2. Se a pasta build\ foi gerada em outro caminho (repo movido) ou com outro
       Python, apaga e regera do zero (o CMakeCache guarda caminhos absolutos).
    3. idf.py build (managed_components\ e baixado automaticamente se faltar).
    4. Com -Port: idf.py -p <porta> flash. Grava bootloader, tabela de
       particoes e app; a NVS (Wi-Fi, token, ajustes) NAO e apagada.

.EXAMPLE
    .\tools\build.ps1
    .\tools\build.ps1 -Port COM4
    .\tools\build.ps1 -Limpar build
    .\tools\build.ps1 -Limpar tudo -SomenteLimpar
#>
param(
    [string]$Port = "",
    [switch]$Clean,
    [string]$Limpar = "",
    [switch]$SomenteLimpar
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot "idf_common.ps1")

function Remove-Caminho {
    param([string]$Caminho)
    if (Test-Path -LiteralPath $Caminho) {
        Write-Host "  removendo $Caminho"
        Remove-Item -LiteralPath $Caminho -Recurse -Force
    }
}

# "-Limpar build,temp" chega como um texto unico quando o script roda via -File.
$niveis = @($Limpar.Split(",") | ForEach-Object { $_.Trim().ToLower() } | Where-Object { $_ })
if ($Clean) { $niveis += "build" }
if ($niveis -contains "tudo") { $niveis = @("build", "temp", "ambiente") }
foreach ($nivel in $niveis) {
    if (@("build", "temp", "ambiente") -notcontains $nivel) {
        throw "Nivel de limpeza invalido: '$nivel' (use build, temp, ambiente ou tudo)."
    }
}

if ($niveis -contains "build") {
    Write-Host "Limpando artefatos de build ..."
    # dependencies.lock NAO entra: e versionado e fixa as versoes dos componentes.
    foreach ($item in @("build", "managed_components", "sdkconfig.old")) {
        Remove-Caminho (Join-Path $FirmwareDir $item)
    }
}
if ($niveis -contains "temp") {
    Write-Host "Limpando temporarios ..."
    $ignorar = @((Join-Path $RepoRoot ".git"), $EnvRoot, (Join-Path $FirmwareDir "releases"))
    Get-ChildItem -LiteralPath $RepoRoot -Recurse -Force -ErrorAction SilentlyContinue |
        Where-Object {
            $caminho = $_.FullName
            -not ($ignorar | Where-Object { $caminho.StartsWith($_, [System.StringComparison]::OrdinalIgnoreCase) }) -and
            (($_.PSIsContainer -and $_.Name -eq "__pycache__") -or
             (-not $_.PSIsContainer -and $_.Extension -in @(".pyc", ".tmp", ".log")))
        } |
        Sort-Object { $_.FullName.Length } -Descending |
        ForEach-Object { Remove-Caminho $_.FullName }
}
if ($niveis -contains "ambiente") {
    Write-Host "Limpando o ambiente ESP-IDF (sera recriado no proximo build) ..."
    Remove-Caminho $EnvRoot
}
if ($SomenteLimpar) {
    Write-Host "Limpeza concluida (sem compilar)."
    return
}

. (Join-Path $PSScriptRoot "activate-esp-idf.ps1")
if (-not $env:IDF_PATH) { throw "Ambiente ESP-IDF nao foi ativado." }

$buildDir = Join-Path $FirmwareDir "build"
$cache = Join-Path $buildDir "CMakeCache.txt"
$regerar = $false
if ((Test-Path $buildDir) -and (Test-Path $cache)) {
    $linhaHome = Select-String -Path $cache -Pattern '^CMAKE_HOME_DIRECTORY:INTERNAL=(.*)$' | Select-Object -First 1
    $linhaPython = Select-String -Path $cache -Pattern '^PYTHON:UNINITIALIZED=(.*)$' | Select-Object -First 1
    $homeCache = if ($linhaHome) { $linhaHome.Matches[0].Groups[1].Value } else { "" }
    $pythonCache = if ($linhaPython) { $linhaPython.Matches[0].Groups[1].Value } else { "" }
    $fwNormalizado = $FirmwareDir.Replace('\', '/').TrimEnd('/')
    if ($homeCache -ne $fwNormalizado -or ($pythonCache -and -not (Test-Path $pythonCache))) {
        Write-Host "build\ gerado em outro caminho/Python ($homeCache); regerando do zero."
        $regerar = $true
    }
}
if ($regerar) {
    Remove-Caminho $buildDir
}

Push-Location $FirmwareDir
try {
    idf.py build
    if ($LASTEXITCODE -ne 0) { throw "idf.py build falhou (codigo $LASTEXITCODE)." }
    if ($Port) {
        idf.py -p $Port flash
        if ($LASTEXITCODE -ne 0) { throw "idf.py flash falhou (codigo $LASTEXITCODE)." }
    }
} finally {
    Pop-Location
}
