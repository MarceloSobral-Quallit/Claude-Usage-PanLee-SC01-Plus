# Firmware arquivado — 1.1.6-sc01plus-rotacao-ip-ociosidade

**Data:** 2026-11-11
**Placa:** Smart Panlee SC01 Plus (ESP32-S3, QFN56 rev v0.2), COM4, MAC `74:4d:bd:57:3c:18`
**Estado:** gravado em COM4 (hash verificado pelo esptool) — **APROVADO** em 2026-11-11.
Usuário confirmou na placa: rotação, IP no rodapé e retorno automático dos Ajustes ("Tudo OK").
Sucedida pela 1.1.7 (correção de TLS), que inclui estas mudanças.

## Objetivo deste firmware

Bump de patch (`1.1.5-sc01plus` → `1.1.6-sc01plus`):

1. **Rotação da tela (Ajustes)** — nova linha "Rotacao da tela: normal / invertida
   (180)". Aplica na hora e persiste na NVS (chave `rot`, namespace `claude`).
   - `bsp_display_set_rotation_180()`: mantém `swap_xy` e espelha os dois eixos
     (`esp_lcd_panel_mirror(flipped, flipped)`). Byte swap, BGR e inversão
     (contrato de cor) não mudam.
   - Touch: `touch_read()` inverte X e Y quando `g_rot180`.
   - Ao alternar, a tela inteira é invalidada para redesenhar. Reset de fábrica
     volta para normal.
   - Retrato (90/270) não foi feito: a UI usa coordenadas fixas de 480x320.
2. **IP no rodapé direito** da tela principal — `IP x.x.x.x` (ou `IP --` sem Wi-Fi),
   mesma fonte e cor do crédito "Marcelo Sobral • v…" (Montserrat 12, `C_FAINT`).
   Atualizado ao montar a tela e a cada 15 s (`IP_REFRESH_MS`).
3. **Ajustes abrindo sozinhos** — causa provável e correção:
   - O único caminho de MAIN para SETTINGS é o `CLICKED` da engrenagem. Logo, as
     aberturas sem toque vêm de toque fantasma no driver manual do FT6336U.
   - O driver antigo aceitava `TD_STATUS & 0x07` (valores 3–7, lixo de ruído/I2C,
     viravam toque), ignorava o flag de evento (lift-up / no-event) e lia status e
     coordenadas em duas transações. Uma única amostra espúria virava
     PRESSED + RELEASED = CLICKED no LVGL.
   - Agora: leitura única 0x02–0x06; `TD_STATUS` precisa estar em 1..2; evento
     precisa ser press-down/contact; o toque só vale depois de 2 leituras válidas
     seguidas a até 30 px (`TOUCH_CONFIRM_*` em `config.h`).
   - Diagnóstico: contadores de amostras rejeitadas (status/evento/coord/isolado)
     logados no serial e em `/sdcard/CLAUDESK.LOG` no máximo 1x/min; cada abertura
     dos Ajustes registra o último toque confirmado.
4. **Retorno automático** — Ajustes e Sobre sem toque por 30 s
   (`SETTINGS_IDLE_TIMEOUT_MS`) voltam para a tela principal (ou para Carregando, se
   ainda não há dados). A tela do servidor NTP fica de fora, para não descartar um
   endereço sendo digitado.

## Origem

- Fonte: snapshot completo em [`src/`](src/) desta pasta, ESP-IDF `v5.5.5-316-g1a1a5aa6513`
  (branch `release/v5.5`), target `esp32s3`, venv `idf5.5_py3.12_env`.
- Build: `.\tools\build.ps1` (novo; regera ambiente/`build\` quando necessário).

## Arquivos e hashes

| Arquivo | SHA-256 |
|---|---|
| `bootloader.bin` | `0273dff4d6d364f0b32372faf6c052e7ea3780586f157b680ecee487c38894d8` |
| `partition-table.bin` | `fd8026bff850ca0dee41c41305160317fffe604dda30a9bd5a701ac82d96fa17` |
| `claude_usage_panlee_sc01_plus.bin` | `3265f75e7ae58b2c312b4d28b920628a218a24e882c1fbd7c8e336ad3bcfb392` |
| `flash_args` | `09b41041b72da9a55c7409c917a029c8c0a048d215872762888020894113742e` |

## Gravação a partir da fonte

```powershell
Copy-Item -Recurse releases\1.1.6-sc01plus-rotacao-ip-ociosidade\src\* firmware\panlee_sc01_plus\ -Force
.\tools\build.ps1 -Port COM4
```

## Restaurar este pacote específico (só o binário, sem recompilar)

```powershell
.\.idf-env\tools\python_env\idf5.5_py3.12_env\Scripts\python.exe -m esptool `
  --chip esp32s3 -p COM4 -b 460800 write_flash `
  --flash_mode dio --flash_freq 80m --flash_size 16MB `
  0x0 releases\1.1.6-sc01plus-rotacao-ip-ociosidade\bootloader.bin `
  0x8000 releases\1.1.6-sc01plus-rotacao-ip-ociosidade\partition-table.bin `
  0x10000 releases\1.1.6-sc01plus-rotacao-ip-ociosidade\claude_usage_panlee_sc01_plus.bin
```

Para voltar à versão anterior aprovada, use o mesmo comando com os arquivos de
`releases/1.1.5-sc01plus-hdr-branco/`.
