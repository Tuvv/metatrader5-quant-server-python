#!/bin/bash

source /scripts/02-common.sh

log_message "RUNNING" "04-install-mt5.sh"

# The KasmVNC/Openbox autostart hook runs again for a new desktop session.
# Avoid starting another MT5 process if the existing session is still alive.
if pgrep -f '[t]erminal64.exe' > /dev/null 2>&1; then
    log_message "INFO" "MT5 is already running; skipping another launch."
    exit 0
fi

# Check if MetaTrader 5 is installed
if [ -e "$mt5file" ]; then
    log_message "INFO" "File $mt5file already exists."
else
    log_message "INFO" "File $mt5file is not installed. Installing..."

    # Set Windows 10 mode in Wine and download and install MT5
    $wine_executable reg add "HKEY_CURRENT_USER\\Software\\Wine" /v Version /t REG_SZ /d "win10" /f
    if [ -s /config/mt5setup.exe ]; then
        log_message "INFO" "Using locally supplied installer /config/mt5setup.exe."
        if ! cp /config/mt5setup.exe /tmp/mt5setup.exe; then
            log_message "ERROR" "Could not copy /config/mt5setup.exe to /tmp/mt5setup.exe."
            exit 1
        fi
    else
        log_message "INFO" "Downloading MT5 installer..."
        if ! curl --fail --location --retry 5 --retry-all-errors --retry-delay 2 \
            --connect-timeout 30 --max-time 300 \
            --output /tmp/mt5setup.exe "$mt5setup_url" >> /var/log/mt5_setup.log 2>&1 || [ ! -s /tmp/mt5setup.exe ]; then
            log_message "ERROR" "Could not download MT5 from $mt5setup_url (network/TLS connection timed out). To bypass container egress restrictions, place the official mt5setup.exe at ./config/mt5setup.exe on the host and restart the container."
            rm -f /tmp/mt5setup.exe
            exit 1
        fi
    fi

    log_message "INFO" "Installing MetaTrader 5..."
    $wine_executable /tmp/mt5setup.exe
    installer_status=$?
    log_message "INFO" "MT5 installer exited with status $installer_status."
    rm -f /tmp/mt5setup.exe
fi

# Recheck if MetaTrader 5 is installed
if [ ! -e "$mt5file" ]; then
    # MT5 may use a different directory name or install path within the Wine prefix.
    installed_mt5file=$(find "/config/.wine/drive_c" -type f -iname "terminal64.exe" -print -quit 2>/dev/null)
    if [ -n "$installed_mt5file" ]; then
        mt5file=$installed_mt5file
    fi
fi

if [ -e "$mt5file" ]; then
    log_message "INFO" "File $mt5file is installed. Running MT5..."
    $wine_executable "$mt5file" &
else
    log_message "ERROR" "MT5 $mt5file was not found in /config/.wine/drive_c. The setup program may have been closed before installation completed; open the VNC desktop, run the MT5 installer, and complete its setup wizard."
fi