#!/bin/bash
# 💫 https://github.com/JaKooLit 💫 #
# Nvidia Uninstaller Script #

## WARNING: DO NOT EDIT BEYOND THIS LINE IF YOU DON'T KNOW WHAT YOU ARE DOING! ##
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Change the working directory to the parent directory of the script
PARENT_DIR="$SCRIPT_DIR/"
cd "$PARENT_DIR" || { echo "${ERROR} Failed to change directory to $PARENT_DIR"; exit 1; }

# Source the global functions script
if ! source "$(dirname "$(readlink -f "$0")")/Global_functions.sh"; then
    echo "Failed to source Global_functions.sh"
    exit 1
fi

# Set the name of the log file to include the current date and time
LOG="Install-Logs/uninstall-$(date +%d-%H%M%S)_nvidia.log"

# Nvidia packages to uninstall
nvidia_pkg=(
    nvidia-470xx-dkms
    nvidia-470xx-settings
    nvidia-470xx-utils
    libva
    libva-nvidia-driver
)

# Uninstall Nvidia packages
printf "${YELLOW} Uninstalling ${SKY_BLUE}Nvidia Packages and Linux headers${RESET}...\n"
for krnl in $(cat /usr/lib/modules/*/pkgbase); do
    for NVIDIA in "${krnl}-headers" "${nvidia_pkg[@]}"; do
        uninstall_package "$NVIDIA" "$LOG"
    done
done

# Remove Nvidia modules from mkinitcpio.conf
if grep -qE '^MODULES=.*nvidia. *nvidia_modeset.*nvidia_uvm.*nvidia_drm' /etc/mkinitcpio.conf; then
    sudo sed -Ei 's/ nvidia nvidia_modeset nvidia_uvm nvidia_drm//' /etc/mkinitcpio.conf 2>&1 | tee -a "$LOG"
    printf "${OK} Nvidia modules removed from /etc/mkinitcpio.conf\n" 2>&1 | tee -a "$LOG"
else
    printf "${INFO} Nvidia modules not found in /etc/mkinitcpio.conf. Skipping...\n" 2>&1 | tee -a "$LOG"
fi

# Rebuild Initramfs
printf "\n%.0s" {1..1}
printf "${INFO} Rebuilding ${YELLOW}Initramfs${RESET}...\n" 2>&1 | tee -a "$LOG"
sudo mkinitcpio -P 2>&1 | tee -a "$LOG"

# Remove Nvidia options from modprobe.d
NVEA="/etc/modprobe.d/nvidia.conf"
if [ -f "$NVEA" ]; then
    sudo rm -f "$NVEA" 2>&1 | tee -a "$LOG"
    printf "${OK} Removed $NVEA\n" 2>&1 | tee -a "$LOG"
else
    printf "${INFO} $NVEA not found. Skipping...\n" 2>&1 | tee -a "$LOG"
fi

# Remove Nvidia options from GRUB
if [ -f /etc/default/grub ]; then
    printf "${INFO} ${YELLOW}GRUB${RESET} bootloader detected\n" 2>&1 | tee -a "$LOG"
    
    sudo sed -i -e 's/ nvidia-drm.modeset=1//' -e 's/ nvidia_drm.fbdev=1//' /etc/default/grub
    printf "${OK} Nvidia options removed from /etc/default/grub\n" 2>&1 | tee -a "$LOG"
    
    # Regenerate GRUB configuration
    sudo grub-mkconfig -o /boot/grub/grub.cfg
    printf "${INFO} ${YELLOW}GRUB${RESET} configuration regenerated\n" 2>&1 | tee -a "$LOG"
fi

# Remove Nvidia options from systemd-boot
if [ -f /boot/loader/loader.conf ]; then
    printf "${INFO} ${YELLOW}systemd-boot${RESET} bootloader detected\n" 2>&1 | tee -a "$LOG"
    
    find /boot/loader/entries/ -type f -name "*.conf" | while read imgconf; do
        sudo sed -i -e 's/ nvidia-drm.modeset=1//' -e 's/ nvidia_drm.fbdev=1//' "$imgconf" 2>&1 | tee -a "$LOG"
        printf "${OK} Nvidia options removed from $imgconf\n" 2>&1 | tee -a "$LOG"
    done
fi

printf "\n%.0s" {1..2}
printf "${OK} Uninstallation completed. Please reboot your system.\n" 2>&1 | tee -a "$LOG"