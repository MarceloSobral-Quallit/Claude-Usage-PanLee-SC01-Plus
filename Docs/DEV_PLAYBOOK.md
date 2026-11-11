# Dev Playbook — Claude Usage Stick (Panlee SC01 Plus)

Decisões técnicas registradas + roadmap de próximos passos. Ver `docs/README.md` para
o estado atual e `protocolo-ciclico-publicacao-exclusao.md` para a disciplina de
validação usada a cada rodada.

## Decisões técnicas e por quê

| Decisão | Alternativa considerada | Por quê |
|---|---|---|
| **LVGL 9.2** (resolve para 9.5.x via `^9.2.2`) | LVGL 8.3.11 (pinado pelo pacote inicial da placa) | A UI original já usa API exclusiva do v9 (`lv_display_create`, `lv_image_create`, `lv_buttonmatrix`); reaproveita ~90% do código de UI quase literal. |
| Histórico/heatmap em **arquivo no microSD** (`HISTORY.DAT`) | Partição LittleFS interna | Decisão do usuário: reaproveitar o slot SD já validado nesta placa em vez de criar uma partição nova. Custo: histórico fica vazio se o cartão for removido. |
| Ambiente ESP-IDF **local ao repositório** (`.idf-env/`, via `tools/setup_esp_idf_env.ps1`) | Instalação global (`~/esp`, `~/.espressif`) | Pedido explícito do usuário: nada deve alterar o ambiente da máquina fora do repo; cada checkout é reprodutível sozinho. |
| Busca de rede (`api.c`/`status.c`) roda em **task FreeRTOS dedicada** | Bloquear a task do LVGL (como o firmware original em Arduino fazia) | Mantém a tela responsiva durante o fetch HTTPS (~1-2s); a task de rede só escreve em variáveis simples, quem aplica na LVGL é a task principal. |
| Task stack sizing: **`CONFIG_ESP_MAIN_TASK_STACK_SIZE=12288`** e **`httpd_config_t.stack_size=8192`** no servidor de onboarding | Defaults do ESP-IDF (3584 / 4096 bytes) | Confirmado em hardware: qualquer task que chame `esp_http_client`/TLS precisa de pilha generosa. Ver `REFERENCIA-HARDWARE-LVGL.md` § armadilhas. |
| `LV_CONF_PATH` definido globalmente via `idf_build_set_property` (guardado por `CMAKE_BUILD_EARLY_EXPANSION`) em `main/CMakeLists.txt` | Depender só de `-Imain` (`LV_CONF_INCLUDE_SIMPLE`) | O componente `lvgl/lvgl` só adiciona `managed_components/` ao seu próprio include path, não `main/` — arquivos internos do LVGL não achavam `lv_conf.h` sem isso. |
| `esp_wifi_set_ps(WIFI_PS_NONE)` logo após `esp_wifi_start()` | Deixar o power-save default | Confirmado em hardware: handshakes TLS consecutivos (ex. API + status.claude.com no mesmo ciclo) falhavam com `PK verify failed` logo após uma transição de power-save do Wi-Fi. |
| `CONFIG_LWIP_SNTP_MAX_SERVERS=2` | Deixar o default (1) | `time_sync_start()` configura 2 servidores (primário + fallback); com o default o SNTP nunca inicializava (log: `Tried to configure more servers than enabled in lwip`), deixando Tendência/Heatmap vazios pra sempre sem nenhum erro visível na tela. |
| "Solicitar PIN no boot: Sim/Não" usa um `FIXED_PIN` interno quando desligado (não um modo "sem senha" de verdade) | Guardar o token sem criptografia quando o PIN estiver desligado | O PIN não é só trava de UI: é o material de derivação da chave AES-256-GCM (`crypto.c`). Desligar a exigência de digitar PIN a cada boot exige recriptografar o token com um PIN fixo conhecido — reduz a proteção a "ofuscação contra dump de flash", documentado explicitamente na tela e no README § Segurança. |
| Servidor NTP primário editável (`g_ntpServer`, NVS, tela `ST_NTP_SERVER`) — aplicado só no **próximo boot** | Reinicializar o SNTP em tempo real ao salvar | `esp_netif_sntp_init()`/`time_sync_start()` só roda uma vez por sessão (guard `s_started`); reconfigurar em tempo real exigiria `esp_netif_sntp_deinit()` + reinit, sem benefício claro para uma configuração que muda raramente. Mais simples e seguro pedir reboot. |
| Relógio do dispositivo exibido como um label separado (`g_hdrClock`) ao lado do wordmark, em vez de concatenado no label de status existente (`g_hdrStatus`) | Concatenar `"HH:MM:SS • atualizado há Xs"` num único label | O label de status já ocupa quase toda a folga horizontal entre o botão de refresh e o botão de engrenagem (~128px); concatenar o relógio ali estourava essa faixa. O wordmark (56×26px) deixa ~84px livres logo à direita, suficiente para o relógio sozinho. |
| **Todo firmware gravado na placa é arquivado em `firmware/panlee_sc01_plus/releases/<versão>-<slug-descritivo>/`** (binários `bootloader.bin`/`partition-table.bin`/`claude_usage_panlee_sc01_plus.bin` + `flash_args` + snapshot completo do código-fonte daquela versão exata em `src/` — `main/`, `CMakeLists.txt`, `sdkconfig.defaults`, `partitions.csv` — + `README.md` com hashes SHA-256), **independente do resultado**. Builds pausados sem confirmação visual/validação final registram o motivo no próprio README. Regra **mandatória** a partir de 2026-08-18. **Retenção (a partir de 2026-11-11):** `releases/` mantém completas só as **3 últimas gravações**, incluindo sempre a instalada na placa. Ao arquivar a 4.ª, a mais antiga é resumida em `Docs/HISTORICO_DESENVOLVIMENTO.md` (objetivo, o que foi feito, resultado, se foi descartada) e só então sai de `releases/`. Não existe mais `releases/descartados/`: gravações pausadas ou reprovadas registram o motivo no próprio README e contam entre as 3. | Só registrar linha em `REGISTRO_DE_BUILDS.md` sem arquivar binário/código-fonte | Mesma regra adotada no projeto irmão `NETPANEL/ESP32-4848S040C_V2` depois de perder os builds intermediários `V0.6.0 BUILD 1`–`4` (gravados na placa, nunca arquivados) sem nenhuma forma de reconstituir o código-fonte exato que gerou aquele `.bin` já em hardware — só sobrou o estado final. O caminho de trabalho (`main/`) é mutável e muda a cada build seguinte; sem snapshot, o histórico de builds fica irrecuperável. |
| **O repositório guarda só fonte e regras** (a partir de 2026-11-11): código, `tools/`, `assets/brand`, documentação/regras e as 3 últimas releases. Nenhum outro firmware/binário fica no projeto: backups da flash (inclusive o original de fábrica) ficam em `_arquivo\SC01Plus\factory-firmware\`, ao lado da pasta do projeto, com cópia no backup externo. `.idf-env/`, `build/` e `managed_components/` são descartáveis (`tools\build.ps1 -Limpar tudo -SomenteLimpar`) e o build recria tudo. | Manter o dump de 16 MB versionado | Repositório público e enxuto: o dump não é fonte, não muda e só serve para restaurar a placa. |

## Roadmap (atualizado via `/roadmap` em 2026-07-29)

### Contexto entendido

O porte está **funcionalmente completo e publicado**: Fases 1–4 do porte original
concluídas, todos os 6 bugs de hardware corrigidos, token OAuth aceito com dados reais
na tela, PIN/dashboard/settings/moments alcançáveis, toggle de PIN no boot
implementado e testado, relógio no dashboard e servidor NTP editável implementados e
confirmados pelo usuário em hardware real, repositório publicado no GitHub (3 commits,
push confirmado). O que resta é validação complementar (não bloqueante) e manutenção
contínua da documentação.

### Suposições

- A placa permanece disponível fisicamente só com o usuário (COM3); toda validação
  em hardware depende do usuário rodar os comandos e reportar o resultado.
- Push/força de git e qualquer outra ação visível/irreversível continuam exigindo
  confirmação explícita a cada vez — nunca assumidas de uma rodada para outra.

### Fase F — Validar `tools/token_bridge.py` contra o device real (pendente)

Objetivo: confirmar a ponte de tokens por sessão contra o device já publicado.

Tarefas:
- Rodar `python3 tools/token_bridge.py --host <ip-do-device>` (ou via mDNS
  `claude-stick.local`, se a resolução mDNS funcionar na máquina do usuário).
- Confirmar que `GET /window` e `POST /tokens` respondem como esperado e que a tela
  "Agora" mostra a linha de tokens da janela.

Validação:
- Saída do script sem erro; label de tokens aparece no dashboard dentro de 15 min.

### Fase G — Resolver a inconsistência de maiúsculas/minúsculas em `Docs/` (pendente decisão do usuário)

Objetivo: alinhar o nome real da pasta versionada no Git (`Docs/`, com D maiúsculo)
com a convenção usada em todos os links relativos do projeto (`docs/`, minúsculo).

Contexto: o Windows é case-insensitive no sistema de arquivos, então todas as edições
feitas nesta sessão usando `docs/...` (minúsculo) caíram na mesma pasta física sem
nenhum aviso — mas o Git preserva o nome com que o arquivo foi adicionado pela
primeira vez (`Docs/`, maiúsculo), e o GitHub (Linux, case-sensitive) respeita essa
grafia. Isso quebra qualquer link markdown do tipo `[texto](docs/arquivo.md)` ao
navegar o repositório publicado, e também quebraria um `git clone` num sistema de
arquivos case-sensitive (Linux/Mac).

Tarefas (exige confirmação explícita antes de executar — é uma mudança estrutural
visível no repositório já publicado):
- `git mv Docs Docs_tmp && git mv Docs_tmp docs` (rename em duas etapas, necessário em
  filesystem case-insensitive) — sem alterar conteúdo de nenhum arquivo.
- Commit dedicado só para o rename.
- Push mediante confirmação separada.

Validação:
- `git ls-files | grep -i ^docs/` mostra todos os caminhos com `docs/` minúsculo.
- Navegar o repositório no GitHub e confirmar que os links relativos (`docs/INDEX.md`
  a partir do README raiz, etc.) resolvem corretamente.

### Fase H — Manutenção contínua

Objetivo: manter a disciplina de registro a cada mudança hardware-sensível.

Tarefas:
- Toda alteração em display/touch/rede/tasks: registrar em
  `docs/REGISTRO_DE_BUILDS.md` (versão, alteração isolada, hash, evidência) — ver
  `protocolo-ciclico-publicacao-exclusao.md`.
- Reavaliar periodicamente se `tools/` (scripts Python) precisa de um venv dedicado
  (hoje só documentado para o ambiente ESP-IDF em si).
- Se o `CLAUDE_CODE_USER_AGENT` em `main/config.h` for revisitado no futuro,
  confirmar contra um `claude --version` real antes de trocar (item não-bloqueante,
  ver `docs/README.md` § pendências).

## Riscos e mitigações

- **Risco**: rename de `Docs/` → `docs/` é uma mudança visível no repositório já
  público. **Mitigação**: só executar mediante confirmação explícita, como commit
  isolado (sem misturar com mudança de conteúdo), e confirmar o resultado no GitHub
  antes de considerar a Fase G concluída.
- **Risco**: `tools/token_bridge.py` nunca foi exercitado contra o firmware atual;
  pode haver deriva de contrato (`/window`, `/tokens`) não percebida até agora.
  **Mitigação**: Fase F testa isso isoladamente, sem depender de mudança de firmware.

## Perguntas pendentes

- O usuário quer que a Fase G (rename `Docs/` → `docs/`) seja executada agora, ou
  fica registrada para uma rodada futura?
- Vale a pena testar `tools/token_bridge.py` (Fase F) nesta rodada, já que o device
  está com token aceito e dashboard funcionando?

## Próximo passo recomendado

Decidir a Fase G (rename de pasta) primeiro, por ser rápida e desbloquear links
corretos no GitHub; em seguida, se houver interesse, validar `tools/token_bridge.py`
(Fase F) como último item pendente antes de considerar o porte 100% fechado.
