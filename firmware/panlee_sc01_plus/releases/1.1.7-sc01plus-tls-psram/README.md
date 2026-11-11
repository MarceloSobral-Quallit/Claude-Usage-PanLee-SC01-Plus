# Firmware arquivado — 1.1.7-sc01plus-tls-psram

**Data:** 2026-11-11
**Placa:** Smart Panlee SC01 Plus (ESP32-S3, QFN56 rev v0.2), COM4, MAC `74:4d:bd:57:3c:18`
**Estado:** gravado em COM4 (hash verificado pelo esptool). Serial por 6 min: 6/6
handshakes TLS validados, `status.claude.com` HTTP 200 nos 2 ciclos; 2ª captura de 5 min:
9/9 validados, status e API HTTP 200 em 3/3 ciclos, 0 `PK verify failed`. **APROVADO**
em 2026-11-11 — usuário confirmou na placa a UI herdada da 1.1.6 ("Tudo OK").

## Objetivo deste firmware

Bump de patch (`1.1.6-sc01plus` → `1.1.7-sc01plus`), sobre a 1.1.6
(rotação, IP no rodapé, filtro de toque fantasma, retorno automático dos Ajustes).

**Erro de certificado intermitente em `status.claude.com`.** Serial da 1.1.6:

```
E esp-x509-crt-bundle: PK verify failed with error 0x4290
E esp-x509-crt-bundle: Certificate matched but signature verification failed
E esp-tls-mbedtls: mbedtls_ssl_handshake returned -0x3000
W STATUS: open failed: ESP_ERR_HTTP_CONNECT
```

`0x4290` = `MBEDTLS_ERR_RSA_PUBLIC_FAILED` (`-0x4280`) + `MBEDTLS_ERR_MPI_ALLOC_FAILED`
(`-0x0010`): faltou memória na verificação RSA da assinatura. O certificado não estava
inválido (o handshake seguinte, do probe, validou normalmente).

Causa: `CONFIG_MBEDTLS_INTERNAL_MEM_ALLOC=y` forçava todo o mbedTLS para a RAM
interna, disputada com Wi-Fi, LVGL (`LV_MEM_SIZE` 96 KiB, estático) e a task de refresh.

Correções:

1. `CONFIG_MBEDTLS_EXTERNAL_MEM_ALLOC=y` (em `sdkconfig.defaults` e no `sdkconfig`
   local): alocações do mbedTLS vão para a PSRAM de 2 MiB (já ativa para `malloc`,
   memtest no boot). Não envolve o buffer do LVGL (ressalva da referência de hardware).
2. `status.c`: se a conexão falhar, tenta mais uma vez após 1 s e loga RAM interna
   livre, maior bloco e PSRAM livre (diagnóstico se voltar a ocorrer).

## Origem

- Fonte: snapshot completo em [`src/`](src/) desta pasta, ESP-IDF `v5.5.5-316-g1a1a5aa6513`
  (branch `release/v5.5`), target `esp32s3`, venv `idf5.5_py3.12_env`.
- Build: `.\tools\build.ps1 -Port COM4`.

## Arquivos e hashes

| Arquivo | SHA-256 |
|---|---|
| `bootloader.bin` | `0273dff4d6d364f0b32372faf6c052e7ea3780586f157b680ecee487c38894d8` |
| `partition-table.bin` | `fd8026bff850ca0dee41c41305160317fffe604dda30a9bd5a701ac82d96fa17` |
| `claude_usage_panlee_sc01_plus.bin` | `7f41b4350ecfecbc7145e9943f85c521ac2b979efd9521e4929058e12c46c897` |
| `flash_args` | `09b41041b72da9a55c7409c917a029c8c0a048d215872762888020894113742e` |

## Gravação a partir da fonte

```powershell
Copy-Item -Recurse releases\1.1.7-sc01plus-tls-psram\src\* firmware\panlee_sc01_plus\ -Force
.\tools\build.ps1 -Port COM4
```

Atenção: o `sdkconfig` local (fora do git) só herda do `sdkconfig.defaults` opções
ainda não definidas. Se ele existir com `CONFIG_MBEDTLS_INTERNAL_MEM_ALLOC=y`, apague-o
(ou rode `.\tools\build.ps1 -Clean` depois de apagá-lo) para que a opção acima valha.

## Restaurar este pacote específico (só o binário, sem recompilar)

```powershell
.\.idf-env\tools\python_env\idf5.5_py3.12_env\Scripts\python.exe -m esptool `
  --chip esp32s3 -p COM4 -b 460800 write_flash `
  --flash_mode dio --flash_freq 80m --flash_size 16MB `
  0x0 releases\1.1.7-sc01plus-tls-psram\bootloader.bin `
  0x8000 releases\1.1.7-sc01plus-tls-psram\partition-table.bin `
  0x10000 releases\1.1.7-sc01plus-tls-psram\claude_usage_panlee_sc01_plus.bin
```

Versão aprovada anterior: `releases/1.1.6-sc01plus-rotacao-ip-ociosidade/`.
