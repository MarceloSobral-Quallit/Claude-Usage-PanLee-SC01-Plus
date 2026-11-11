# Histórico de desenvolvimento do firmware — Claude Usage Stick (Panlee SC01 Plus)

Histórico compilado dos `README.md` das releases que **não** ficam mais completas em
`releases/` (regra: só as 3 últimas gravadas, incluindo a instalada, ficam com binários e
snapshot). Cada entrada resume o que se buscou resolver, o que foi feito e o resultado.
Releases marcadas como **descartado** foram tentativas reprovadas ou superadas: consulte-as
antes de repetir uma abordagem.

**Como recuperar uma release completa:** o histórico do GitHub foi reiniciado em 11/11/2026; o histórico anterior (até o commit `dceed72`, com todas as releases completas) está no backup `C:\QSI_DESENV\ESP32\_backups_git\Claude-Usage-PanLee-SC01-Plus_ate_dceed72.bundle`: `git fetch <bundle> main:historico-antigo` e depois `git checkout historico-antigo -- "firmware/panlee_sc01_plus/releases/<pasta>"`.

## Releases completas mantidas em `releases/`

- `1.1.5-sc01plus-hdr-branco`
- `1.1.6-sc01plus-rotacao-ip-ociosidade`
- `1.1.7-sc01plus-tls-psram`

## Releases resumidas (5)

## Linha 1.1.x

### 1.1.0-sc01plus-data-limiares5pct-credito

*Firmware arquivado — 1.1.0-sc01plus-data-limiares5pct-credito*

- **Data:** 2026-08-18
- **Estado:** SUPERADA — ver `../1.1.1-sc01plus-data-alinhada-direita/`.

**Objetivo** (Objetivo deste firmware):

Bundle de 4 mudanças no dashboard principal + bump de versão:
1. **Data acima do relógio** no cabeçalho (`g_hdrDate`, formato `DD/MM/AAAA`) — o
   ponteiro já existia declarado (`app_state.h`/`app_state.c`) mas nunca tinha sido
   ligado à UI; agora é criado em `ui_main()` e atualizado a cada segundo junto com
   o relógio em `set_hdr_status()`.
2. **Data + relógio deslocados 2 caracteres para a direita** — a largura é medida em
   tempo de execução (label temporário `"00"` na própria fonte do relógio,
   `lv_font_montserrat_12`, via `lv_obj_get_width`), não um valor de pixel
  (...)

### 1.1.1-sc01plus-data-alinhada-direita

*Firmware arquivado — 1.1.1-sc01plus-data-alinhada-direita*

- **Data:** 2026-08-18
- **Estado:** SUPERADA — ver `../1.1.2-sc01plus-data-cor-igual-hora/`. Alinhamento estava correto, mas a cor da data (`C_FAINT`) divergia da hora (`C_MUTED`), o que o usuário percebeu como "a hora parece BOLD" (efeito de contraste/anti-aliasing, não de fonte). Corrigido igualando as cores.

**Objetivo** (Objetivo deste firmware):

Bump de patch (`1.1.0-sc01plus` → `1.1.1-sc01plus`) para corrigir o alinhamento da
data no cabeçalho do dashboard, que tinha sido gravado antes sem incrementar versão
(ver nota de correção de processo em
`../1.1.0-sc01plus-data-limiares5pct-credito/README.md`).
- **Data alinhada pela borda direita com a hora** (mesma fonte,
  `lv_font_montserrat_12`) — antes as duas começavam no mesmo x (alinhadas pela
  esquerda), mas `DD/MM/AAAA` (10 caracteres) é mais largo que `HH:MM:SS` (8
  caracteres), então a borda direita da data ultrapassava a da hora. Agora a largura
  (...)

### 1.1.2-sc01plus-data-cor-igual-hora

*Firmware arquivado — 1.1.2-sc01plus-data-cor-igual-hora*

- **Data:** 2026-08-18
- **Estado:** SUPERADA — ver `../1.1.3-sc01plus-data-alinhamento-dinamico/`. Cor corrigida, mas o alinhamento continuava incorreto: a posição da data era calculada uma única vez no boot com uma sonda de largura fixa ("00:00:00" / "00/00/0000"), e os dígitos do Montserrat não são monoespaçados — qualquer hora/data real com dígitos diferentes de zero rendeiriza com largura ligeiramente diferente da sonda. Corrigido recalculando a posição a cada tick com a largura real do texto.

**Objetivo** (Objetivo deste firmware):

Bump de patch (`1.1.1-sc01plus` → `1.1.2-sc01plus`) para corrigir a cor da data no
cabeçalho do dashboard.
- **Cor da data igualada à da hora** (`C_MUTED` nos dois, antes a data usava
  `C_FAINT`). A fonte já era a mesma (`lv_font_montserrat_12`) desde `1.1.0`, mas o
  usuário reportou que a hora "aparentava ser BOLD" comparada à data — a causa real
  era contraste, não peso de fonte: `C_MUTED` (0x8C8C98, mais claro) sobre fundo
  escuro renderiza com anti-aliasing mais pesado que `C_FAINT` (0x5C5C68, mais
  escuro/baixo contraste), o que a olho nu parece negrito. Igualando a cor, o
  (...)

### 1.1.3-sc01plus-data-alinhamento-dinamico

*Firmware arquivado — 1.1.3-sc01plus-data-alinhamento-dinamico*

- **Data:** 2026-08-18
- **Estado:** validação visual **confirmada pelo usuário** (alinhamento OK) — mas SUPERADA em disco pela gravação seguinte, ver `../1.1.4-sc01plus-deslocamento-3-caracteres/` (mesmo alinhamento, só mais 1 caractere de deslocamento a pedido do usuário).

**Objetivo** (Objetivo deste firmware):

Bump de patch (`1.1.2-sc01plus` → `1.1.3-sc01plus`) para corrigir a causa raiz do
desalinhamento entre data e hora, que persistia mesmo depois do ajuste de `1.1.1`.

**O que foi feito** (Correção):

`set_hdr_status()` (chamada uma vez no boot via `refresh_ui_values()` e depois a
cada segundo via `dashboard_animate()` → `dash_tick()`) agora recalcula a posição X
da data **a cada tick**, usando `lv_obj_get_width()` sobre o texto **real** que
acabou de ser definido em cada label (não uma sonda). A borda direita da data é
sempre `borda_direita_da_hora_agora - largura_da_data_agora`, correta para
qualquer combinação de dígitos. Ver `src/main/ui_dashboard.c`, `set_hdr_status()`.
A posição X definida em `ui_main()` para a data agora é só um valor inicial
provisório (mesmo `hdrX` do relógio) — corrigido no primeiro tick, que roda antes da
tela ficar visível (dentro do próprio `ui_main()`, via `refresh_ui_values()`).

### 1.1.4-sc01plus-deslocamento-3-caracteres

*Firmware arquivado — 1.1.4-sc01plus-deslocamento-3-caracteres*

- **Data:** 2026-08-18
- **Estado:** SUPERADA — ver `../1.1.5-sc01plus-hdr-branco/` (release aprovada). Deslocamento estava correto, mudança seguinte foi só de cor de texto.

**Objetivo** (Objetivo deste firmware):

Bump de patch (`1.1.3-sc01plus` → `1.1.4-sc01plus`). Usuário confirmou visualmente
que o alinhamento entre data e hora ficou correto em `1.1.3` e pediu mais 1 caractere
de deslocamento à direita para o bloco data+hora (total agora: 3 caracteres, antes 2).
- `ui_main()`: a sonda usada para medir o deslocamento (`hdrDxProbe`) passou de
  `"00"` (2 caracteres) para `"000"` (3 caracteres) — a largura ainda é medida em
  tempo de execução na própria fonte do relógio (`lv_font_montserrat_12`), não um
  valor de pixel hardcoded. Ver `src/main/ui_dashboard.c`, `ui_main()`.
- Mantém a correção de `1.1.3`: alinhamento da borda direita recalculado a cada tick
  (...)
