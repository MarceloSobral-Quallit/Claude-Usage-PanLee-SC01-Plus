# Requisitos de compilação — ambiente local ao repositório

Este projeto mantém o ambiente de build (checkout do ESP-IDF + toolchain + venv
Python) **dentro do próprio repositório**, em `.idf-env/` (fora do controle de
versão — ver `.gitignore`), em vez de instalar globalmente em `~/esp` ou
`~/.espressif` como o instalador oficial faz por padrão. Isso significa:

- Nada é instalado no Python global da máquina nem em pastas fora deste repositório.
- Cada checkout deste repositório tem sua própria versão do ESP-IDF/toolchain,
  sem conflitar com outros projetos ESP-IDF que você tenha na mesma máquina.
- O único custo é espaço em disco: se você já tem ESP-IDF instalado globalmente,
  isso baixa uma cópia adicional (não compartilha).

## O que é versionado vs. o que é baixado

| Versionado no git | Baixado por `tools/setup_esp_idf_env.ps1` (gitignored) |
|---|---|
| `tools/setup_esp_idf_env.ps1` (script de instalação/reparo) | `.idf-env/esp-idf/` — checkout do framework ESP-IDF |
| `tools/activate-esp-idf.ps1` (script de ativação) | `.idf-env/tools/` — toolchain (GCC Xtensa) + venv Python próprio do ESP-IDF (`python_env/idf5.5_py3.12_env`) |
| `tools/build.ps1` (compila e, com `-Port`, grava) | `firmware/panlee_sc01_plus/build/` e `managed_components/` |
| `tools/idf_common.ps1` (funções comuns: Python suportado, checagem do ambiente) | |
| Este documento | |

**Nenhum binário de toolchain é commitado no git.** Commitar o ESP-IDF e o
toolchain (vários GB, específicos de cada sistema operacional) infla o
repositório sem necessidade — o padrão do ecossistema (equivalente a
`node_modules/` ou `.venv/`) é versionar só o script que reproduz o ambiente,
não o ambiente em si. O que fica local ao repo (em vez de global na máquina) é
**onde** esses downloads são colocados, não o fato de existirem.

## Requisitos

- Windows 10/11 com PowerShell 7+ (ou o Windows PowerShell 5.1 padrão).
- Git (já usado pelo próprio repositório).
- **Python 3.12** instalado no sistema para todos os usuários
  (`C:\Program Files\Python312`). É a única versão aceita pelos scripts
  (`$IdfPythonVersion` em `tools/idf_common.ps1`); serve só para criar o venv do
  ESP-IDF, nenhuma dependência é instalada nele diretamente.
- ~6–8 GiB livres em disco (checkout do ESP-IDF + submódulos + toolchain).
- Conexão à internet para a primeira instalação (`git clone` + download do
  toolchain); depois disso, compilar não precisa mais de rede.

## Uso

```powershell
.\tools\build.ps1                # compila
.\tools\build.ps1 -Port COM4     # compila e grava (a NVS — Wi-Fi, token, ajustes — é preservada)
.\tools\build.ps1 -Limpar build  # apaga build\, managed_components\ etc. e recompila
.\tools\build.ps1 -Limpar tudo -SomenteLimpar   # limpa tudo (inclusive .idf-env) e sai
```

Níveis de `-Limpar` (combináveis com vírgula, ex.: `-Limpar build,temp`):

| Nível | Remove | Recriado por |
|---|---|---|
| `build` | `build\`, `managed_components\`, `dependencies.lock`, `sdkconfig.old` | próximo build |
| `temp` | `__pycache__`, `*.pyc`, `*.tmp`, `*.log` (fora de `releases\` e `.git`) | — |
| `ambiente` | `.idf-env\` inteiro (ESP-IDF, toolchain, venv) | próximo build (baixa de novo) |
| `tudo` | os três acima | — |

O `sdkconfig` local nunca é apagado. `-Clean` continua aceito (equivale a `-Limpar build`).

`build.ps1` sempre regera/baixa o que faltar, sem passo manual:

1. Ativa o ambiente (`activate-esp-idf.ps1`). Se o ESP-IDF, o toolchain ou o venv
   estiverem ausentes ou quebrados — por exemplo, um venv cujo Python base foi
   desinstalado, ou o ESP-IDF fora do commit fixado —, roda `setup_esp_idf_env.ps1` antes.
2. O setup remove venvs obsoletos (outra versão de Python ou Python base inexistente)
   e o `idf-env.json` que aponte para outro caminho do repo, e roda o `install.ps1`
   oficial com o Python 3.12 na frente do PATH, recriando o venv e baixando os
   pacotes e ferramentas que faltarem.
3. Se `build\` foi gerado em outro caminho (repo movido) ou com um Python que não
   existe mais, apaga e regera do zero.
4. `idf.py build` baixa `managed_components\` se necessário.

Para usar `idf.py` direto num terminal: `. .\tools\activate-esp-idf.ps1`
(dot-sourcing). `setup_esp_idf_env.ps1` é reentrante: se `.idf-env/esp-idf` já
existir, ele não reclona, só o coloca no commit fixado.

## Versão do ESP-IDF usada

O ambiente é sempre recriado no **commit exato** que gerou as releases aprovadas:
`1a1a5aa6513592623d6b841ab8c9f3ef61eb9dfd` (`v5.5.5-316-g1a1a5aa6513`, branch
`release/v5.5`), definido em `tools/idf_common.ps1` (`$IdfBranch`/`$IdfCommit`). A ponta
da branch muda com o tempo; fixar o commit garante o mesmo binário ao reconstruir o
ambiente do zero. Para trocar de versão, altere `$IdfCommit` (e registre o motivo em
`REGISTRO_DE_BUILDS.md`).

Os componentes do ESP-IDF Component Manager também têm versão exata:
`main/idf_component.yml` fixa `lvgl/lvgl 9.5.0`, `esp_lcd_st7796 1.4.0` e `mdns 1.11.3`, e
o `dependencies.lock` (versionado desde 11/11/2026) fixa as indiretas. Antes eram faixas
(`^9.2.2`) e o lock era ignorado: ao recriar o ambiente o build baixava LVGL 9.6.0 e
gerava outro binário. Com a fixação, a reconstrução do zero reproduziu a 1.1.7 gravada
byte a byte, exceto data/hora de compilação e hashes do cabeçalho.

## Por que esta abordagem (e quando ela NÃO é a certa)

Válida para este projeto porque:

- É um único firmware, então não há ganho em compartilhar um ESP-IDF global
  entre "vários projetos" na mesma máquina.
- O pedido explícito do projeto é evitar qualquer alteração no ambiente do
  desenvolvedor fora do repositório (venv sempre, nunca instalação global).
- Reprodutibilidade: qualquer pessoa que clonar o repositório e rodar um único
  script reproduz exatamente o ambiente esperado, sem depender do que já está
  (ou não) instalado globalmente na máquina dela.

Ressalva: se você já tem um ESP-IDF 5.5.x global configurado (ex.: o atalho
"ESP-IDF 5.5 PowerShell" do instalador oficial) e não se importa em compartilhá-lo
entre projetos, pode simplesmente usá-lo em vez deste script — os dois convivem
sem conflito, já que `activate-esp-idf.ps1` só afeta a sessão atual do terminal.
