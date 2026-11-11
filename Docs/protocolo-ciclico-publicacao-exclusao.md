# Protocolo Cíclico — Publicação e Exclusão

Adaptado de `C:\DESENV\PROJECT_TEMPLATE\ROADMAP_BLOCO_PROTOCOLO_CICLICO.md` (versão
curta) para o contexto deste projeto: firmware embarcado validado em hardware real,
sem toolchain de compilação disponível no ambiente do agente — toda validação
técnica depende do usuário compilar/gravar/testar na própria máquina e placa.

## Objetivo

Garantir alinhamento contínuo entre documentação (`docs/`), implementação
(`firmware/panlee_sc01_plus/`), execução técnica (build/flash/monitor em hardware
real) e a eventual publicação/exclusão de conteúdo no repositório GitHub.

## Ciclo operacional (rodada)

1. **Contrato** — confirmar que `docs/README.md` (estado atual) e
   `docs/DEV_PLAYBOOK.md` (decisões/roadmap) descrevem exatamente o comportamento
   real do firmware, sem contradição com o código em `main/`.
2. **Implementação** — ajustar código apenas quando houver divergência entre o
   contrato documentado e o comportamento esperado (ou quando o usuário pedir uma
   mudança explícita).
3. **Execução técnica** — compilar (`idf.py build`), gravar (`idf.py -p COM3
   flash`) e observar o log serial (`idf.py -p COM3 monitor`) em hardware real. Uma
   alteração isolada por rodada sempre que mexer em display/touch/rede/tasks (ver
   `REGRAS_DESENVOLVIMENTO_LCD.md`).
4. **Arquivamento do firmware (mandatório, toda gravação)** — copiar os binários do
   build (`bootloader.bin`, `partition-table.bin`,
   `claude_usage_panlee_sc01_plus.bin`, `flash_args`) e um snapshot completo do
   código-fonte daquela versão (`main/`, `CMakeLists.txt`, `sdkconfig.defaults`,
   `partitions.csv`) para
   `firmware/panlee_sc01_plus/releases/<versão>-<slug-descritivo>/`, com hashes
   SHA-256 e `README.md` próprio (ver `DEV_PLAYBOOK.md` § Decisões técnicas). Vale para
   toda gravação, aprovada ou não. Mantêm-se completas só as 3 últimas gravações
   (incluindo a instalada); a mais antiga é resumida em
   `Docs/HISTORICO_DESENVOLVIMENTO.md` antes de sair de `releases/`.
5. **Auditoria de consistência** — buscar e corrigir contradições entre `docs/`,
   `README.md` da raiz e o código (ex.: referências a arquivos renomeados/movidos,
   valores de configuração citados em prosa que não batem mais com
   `sdkconfig.defaults`/`main/config.h`).

## Critério de aprovação de uma rodada

Uma rodada só é aprovada quando:

1. o contrato (`docs/README.md` + `DEV_PLAYBOOK.md`) está sem contradições;
2. o código em `main/` está aderente ao que os documentos descrevem;
3. as validações técnicas foram aprovadas (build limpo + evidência de hardware,
   quando a mudança for hardware-sensível);
4. as evidências da rodada foram registradas em `docs/REGISTRO_DE_BUILDS.md`;
5. toda gravação na placa desta rodada foi arquivada em
   `firmware/panlee_sc01_plus/releases/<versão>-<slug>/`, e releases que saíram das 3
   últimas foram resumidas em `Docs/HISTORICO_DESENVOLVIMENTO.md` — ver passo 4 acima.

## Evidências da rodada

Registrar, para cada rodada hardware-sensível, em `docs/REGISTRO_DE_BUILDS.md`:

1. comandos executados (`idf.py build` / `flash` / `monitor`);
2. arquivos alterados;
3. resultado (aprovada ou pendente, com o motivo);
4. riscos ou pendências que ficaram em aberto;
5. link para a pasta arquivada em `firmware/panlee_sc01_plus/releases/`.

## Publicação no GitHub — regra específica deste projeto

Diferente da rotina documental (que roda automaticamente a cada `/roadmap`), as
etapas de **publicação** (`git commit`, `git remote add`, `git push`) para
`https://github.com/MarceloSobral-Quallit/Claude-Usage---PanLee-SC01-Plus`
**nunca são executadas automaticamente** — cada uma exige confirmação explícita do
usuário, uma de cada vez (ver `DEV_PLAYBOOK.md` § Fase D). Antes de qualquer commit,
revisar `git status`/`git diff` para garantir que nenhum segredo (`wifi_cred.txt`,
tokens, blobs cifrados de teste) está incluído.

Este projeto não é uma aplicação web — a seção de `web_publish_manifest.json` do
template não se aplica aqui.
