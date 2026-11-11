# Firmware arquivado — 1.1.5-sc01plus-hdr-branco

**Data:** 2026-08-18
**Placa:** Smart Panlee SC01 Plus (ESP32-S3, QFN56 rev v0.2), COM3, MAC `74:4d:bd:57:3c:18`
**Estado:** gravado em COM3 — **APROVADO**. Usuário confirmou visualmente na placa
física: "Ficou perfeito agora."

## Objetivo deste firmware

Bump de patch (`1.1.4-sc01plus` → `1.1.5-sc01plus`). Cor de texto de hora, data e do
estado normal da indicação de atualização ("atualizado há Xmin") trocada de cinza
(`C_MUTED`, `#8C8C98`) para branco (`C_TEXT`, `#F2F0EC` — o mesmo branco já usado no
resto da UI), a pedido do usuário.

- `g_hdrClock` e `g_hdrDate`: cor `C_TEXT` desde a criação em `ui_main()`.
- `g_hdrStatus`: cor `C_TEXT` só no estado normal ("atualizado há Xs"/"Xmin"), em
  `set_hdr_status()`. Os estados "atualizando..." (`C_ACCENT`, laranja) e "falha ao
  atualizar" (`C_BAD`, vermelho) mantidos como estavam — carregam significado, não
  são apenas texto secundário.

## Origem

- Fonte: snapshot completo em [`src/`](src/) desta pasta, ESP-IDF `v5.5.5-316-g1a1a5aa6513`
  (branch `release/v5.5`), target `esp32s3`.
- Componentes (`src/main/idf_component.yml`): `espressif/esp_lcd_st7796 ^1.4.0`,
  `lvgl/lvgl ^9.2.2`, `espressif/mdns ^1.3.0`.

## Arquivos e hashes

| Arquivo | SHA-256 |
|---|---|
| `bootloader.bin` | `3a55b9ceb3a90d31ca02b88c6fa6c2d66fa6170700390c59edf3e2cebb4b1ac9` |
| `partition-table.bin` | `fd8026bff850ca0dee41c41305160317fffe604dda30a9bd5a701ac82d96fa17` |
| `claude_usage_panlee_sc01_plus.bin` | `ebd750c1605ed19f2c058270d3329d62d617f413834d15eaac38b523709a34ad` |
| `flash_args` | `09b41041b72da9a55c7409c917a029c8c0a048d215872762888020894113742e` |

## Gravação a partir da fonte

```powershell
Copy-Item -Recurse releases\1.1.5-sc01plus-hdr-branco\src\* firmware\panlee_sc01_plus\ -Force
. .\tools\activate-esp-idf.ps1
Set-Location firmware\panlee_sc01_plus
idf.py set-target esp32s3
idf.py -p COM3 flash
```

## Restaurar este pacote específico (só o binário, sem recompilar)

```powershell
.\.idf-env\tools\python_env\idf5.5_py3.13_env\Scripts\python.exe -m esptool `
  --chip esp32s3 -p COM3 -b 460800 write_flash `
  --flash_mode dio --flash_freq 80m --flash_size 16MB `
  0x0 releases\1.1.5-sc01plus-hdr-branco\bootloader.bin `
  0x8000 releases\1.1.5-sc01plus-hdr-branco\partition-table.bin `
  0x10000 releases\1.1.5-sc01plus-hdr-branco\claude_usage_panlee_sc01_plus.bin
```

Confira os hashes SHA-256 acima antes de gravar. O firmware original de fábrica
(`1.0.0-sc01plus`, dump completo de 16 MB) está preservado fora do repositório, no
arquivo local ao lado da pasta do projeto:
`_arquivo\SC01Plus\factory-firmware\backup_Original_1.0.0-sc01plus_2026-08-18.bin`
(SHA-256 `63b0e1fa233f3343f92b23979a47cf3a785c70e587ba0bdc9fc13c137b1c5191`).
