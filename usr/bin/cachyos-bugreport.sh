#!/usr/bin/env bash
# CachyOS bug reporting shell script.  This shell
# script will generate a log file named "cachyos-bug-report.log".

set -euo pipefail

LOG_FILENAME="${LOG_FILENAME:-"cachyos-bugreport.log"}"
OLD_LOG_FILENAME=cachyos-bugreport.log.old

ask_yes_no(){
    local question="${1}"
    local answer=""
    while ! printf '%s' "${answer}" | grep -q '^\([Yy]\(es\)\?\|[Nn]\(o\)\?\)$'; do
        printf '%s' "${question} [Y]es/[N]o: "
        read -r answer
    done

    if printf '%s' "${answer}" | grep -q '^[Nn]\(o\)\?$'; then
        return 1
    fi
}

check_root(){
    # Check that we are root, required for dmesg
    if [ "$(id -u)" -ne 0 ]; then
        echo "ERROR: Please run $(basename "$0") as root." >&2
        exit 1
    fi
}


# move any old log file
check_oldlog() {
    if [ -f "$LOG_FILENAME" ]; then
        mv "$LOG_FILENAME" "$OLD_LOG_FILENAME"
    fi
}


check_wpermission() {
    if ! touch "$LOG_FILENAME" 2>/dev/null; then
        cat << EOF >&2

ERROR: Working directory is not writable; please cd to a directory
       where you have write permission so that the $LOG_FILENAME
       file can be written.

EOF
        exit 1
    fi
}

get_installed_packages() {
    if [ -e /var/lib/pacman/sync/cachyos-v4.db ]; then
        pacman -Ss | grep --color=never "^cachyos-v4/.*\[installed\]" || true
    elif [ -e /var/lib/pacman/sync/cachyos-v3.db ]; then
        pacman -Ss | grep --color=never "^cachyos-v3/.*\[installed\]" || true
    elif [ -e /var/lib/pacman/sync/cachyos-znver4.db ]; then
        pacman -Ss | grep --color=never "^cachyos-znver4/.*\[installed\]" || true
    else
        echo "znver4, v4 or v3 repositories are not used"
    fi
}

bugreport() {
    echo "Starting with bugreport"

    cat << EOF >"$LOG_FILENAME"
____________________________________________

Start of CachyOS bug report log file. Please send this report,
along with a description of your bug, to CachyOS.

Date: $(date)
uname: $(uname -a)
cmdline: $(cat /proc/cmdline)

____________________________________________
Getting Hardware Information

### CPU
$(lscpu)

### Memory
$(lsmem)
$(free -h)

### Swap
$(swapon --show)
$(cat /proc/swaps)

### PCI devices and drivers
$(lspci -nnk)

### USB devices
$(lsusb)

### Block devices
$(lsblk -e7 -o NAME,PATH,TYPE,SIZE,FSTYPE,FSVER,MOUNTPOINTS,MODEL,TRAN,ROTA)

### DMI / motherboard / BIOS
DMI BIOS vendor: $(cat /sys/class/dmi/id/bios_vendor 2>/dev/null || echo "N/A")
DMI BIOS version: $(cat /sys/class/dmi/id/bios_version 2>/dev/null || echo "N/A")
DMI BIOS date: $(cat /sys/class/dmi/id/bios_date 2>/dev/null || echo "N/A")
DMI board vendor: $(cat /sys/class/dmi/id/board_vendor 2>/dev/null || echo "N/A")
DMI board name: $(cat /sys/class/dmi/id/board_name 2>/dev/null || echo "N/A")
DMI board version: $(cat /sys/class/dmi/id/board_version 2>/dev/null || echo "N/A")
DMI product name: $(cat /sys/class/dmi/id/product_name 2>/dev/null || echo "N/A")
DMI product version: $(cat /sys/class/dmi/id/product_version 2>/dev/null || echo "N/A")

### Kernel modules
$(lsmod)

### Network interfaces
$(ip -details link show)

### Network addresses
$(ip -details address show)

### GPU / DRM
$(find /sys/class/drm -maxdepth 1 -type l -printf '%f\n' 2>/dev/null | sort)

____________________________________________
Getting Scheduler information

sched-ext:
$(grep -R "" /sys/kernel/sched_ext/ 2>/dev/null || echo "sched_ext not available")

$(journalctl --output cat -k | grep -i scheduler || true)

____________________________________________

dmesg

$(dmesg)

____________________________________________
journalctl of current boot

$(journalctl -b -p 4..1)
____________________________________________
journalctl of previous boot

$(journalctl -b -1 -p 4..1 2>/dev/null || echo "No previous boot log available")

____________________________________________

Installed packages

$(get_installed_packages)
--------------------------------------------
EOF
}

upload() {
    if ask_yes_no 'Do you want to upload this log to https://paste.cachyos.org?'; then
        echo "Uploading Log"
        paste-cachyos "$LOG_FILENAME"
    else
        echo "Not uploading Log"
    fi

}

check_root
check_oldlog
check_wpermission
bugreport
redact
upload
