# mysettings

Персональный набор настроек CachyOS под конкретную машину:

* **Плата**: HUANANZHI X99-8M-F (Intel C220/B85), desktop, без батареи
* **CPU**: Intel Xeon E5-2660 v3 (Haswell-EP, AVX2 → репозиторий `cachyos-v3`)
* **RAM**: 31 GiB, swap только ZRAM (zstd, размер = RAM, priority 100), `zswap.enabled=0`
* **GPU**: NVIDIA GTX 1660 Ti (Turing), `linux-cachyos-nvidia-open`
* **Диски**: 2× SATA SSD (HDD/NVMe нет)
* **Звук**: USB-аудио C-Media (PipeWire/WirePlumber), встроенный HDA не используется
* **Сеть**: Realtek RTL8111 (Ethernet), Wi-Fi нет
* **Прочее**: KDE Plasma, Secure Boot (user), `nowatchdog` в cmdline

Собирается в пакет `mysettings`.

## udev (`usr/lib/udev/rules.d/`)

* **I/O scheduler** (`60-ioschedulers.rules`): для SATA SSD (`rotational=0`) назначается
  `adios` (Adaptive Deadline I/O Scheduler, входит в linux-cachyos). HDD и NVMe в системе нет.
* **SATA Link Power Management** (`50-sata.rules`): `max_performance` для SATA-хостов,
  которые поддерживают смену политики (`link_power_management_supported=1`).
* **NVIDIA Runtime PM** (`71-nvidia.rules`): `power/control=auto` при бинде драйвера
  `nvidia`, `on` при отвязке.
* **Права для аудио**: `/dev/hpet` → группа `audio`
  (`40-hpet-permissions.rules`); `/dev/cpu_dma_latency` → `root:audio 0660`
  (`99-cpu-dma-latency.rules`). `/dev/rtc0` намеренно не трогаем — systemd оставляет
  группу `clock`.

## sysctl (`usr/lib/sysctl.d/70-cachyos-settings.conf`)

* `vm.swappiness = 150` — под ZRAM: анонимные страницы сжимаются в RAM, а не вытесняются из page cache
* `vm.vfs_cache_pressure = 50`
* `vm.dirty_bytes = 268435456`, `vm.dirty_background_bytes = 67108864`, `vm.dirty_writeback_centisecs = 1500`
* `vm.page-cluster = 0`
* `kernel.nmi_watchdog = 0`, `kernel.unprivileged_userns_clone = 1`
* `kernel.printk = 3 3 3 3`, `kernel.kptr_restrict = 2`
* `net.core.netdev_max_backlog = 4096`, `fs.file-max = 2097152`

## modprobe (`usr/lib/modprobe.d/`)

* **`blacklist.conf`** — чёрный список под это железо:
  watchdog (`iTCO_wdt`, `wdat_wdt`), EDAC (`sb_edac`), служебные модули NVIDIA
  (`i2c_nvidia_gpu`, `ucsi_ccg`, `mxm_wmi`), встроенный/HDMI-звук (`snd_hda_intel`,
  `snd_seq*`), PS/2 (`psmouse`, `serio_raw`), KVM, FDD/LPT, SPI-доступ к BIOS-флешу,
  `joydev`/`mousedev`/`mac_hid`/`pcspkr`/`gpio_ich`.
* **`nvidia.conf`**: `NVreg_InitializeSystemMemoryAllocations=0`.
* `nouveau` блэклистится пакетом `nvidia-utils`, здесь не дублируется.

## systemd (`usr/lib/systemd/`)

* `zram-generator.conf`: `compression-algorithm = zstd`, `zram-size = ram`, `swap-priority = 100`
* `journald.conf.d/00-journal-size.conf`: `SystemMaxUse=50M`
* `system.conf.d/00-timeout.conf` и `user.conf.d/00-timeout.conf`: 15s / 10s
* `system.conf.d/10-limits.conf`: `DefaultLimitNOFILE=2048:2097152`;
  `user.conf.d/10-limits.conf`: `1024:1048576`
* `timesyncd.conf.d/10-timesyncd.conf`: `time.cloudflare.com` + fallback NTP
* `user@.service.d/delegate.conf`: делегирование `cpu cpuset io memory pids`

## tmpfiles (`usr/lib/tmpfiles.d/`)

* `coredump.conf`: чистка coredump старше 3 дней
* `thp.conf`: `transparent_hugepage/defrag = defer+madvise`
* `thp-shrinker.conf`: `khugepaged/max_ptes_none = 409` (kernel 6.12+)

## Прочее

* `etc/security/limits.d/20-audio.conf`: `@audio - rtprio 99`, `@audio - nice -11`
* `etc/debuginfod/cachyos.urls`: `https://debuginfod.cachyos.org`
* `usr/lib/modules-load.d/ntsync.conf`: `ntsync` (Wine/Proton)
* `usr/lib/NetworkManager/conf.d/dns.conf`: `dns=systemd-resolved`

## Скрипты (`usr/bin/`)

* **`cachyos-bugreport.sh`** — баг-репорт (root) с вычисткой персональных данных
* **`kerver`** — версия ядра, x86_64-support, CPU-конфиг, планировщики
* **`paste-cachyos`** — загрузка файла/stdin на `https://paste.cachyos.org`
* **`sbctl-batch-sign`** — пакетная подпись файлов для Secure Boot (требует root)

## Намеренно убрано

Правила/файлы, не относящиеся к этому железу: Wi-Fi regdomain (`iw-set-regdomain`),
управление питанием `snd-hda-intel`, `hdparm`-правила для HDD, `pci-latency`,
GNOME/touchpad-настройки, AMD GPU, `game-performance`/`topmem`/`zink-run`/`dlss-swapper`,
`rtkit-daemon` override (rtkit не установлен — PipeWire использует RT через `limits.d`).

## Установка

```sh
makepkg -si     # собранный пакет mysettings
```

После обновления пакета убедитесь, что старые пользовательские копии
(например, `/etc/modprobe.d/blacklist-driver.conf`) удалены — теперь всё содержится
в пакете.
