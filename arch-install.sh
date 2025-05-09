#!/bin/bash

# Set variables for partition paths
EFI_PART=/dev/nvme0n1p1       # EFI partition
SWAP_PART=/dev/nvme0n1p2      # Swap partition
ROOT_PART=/dev/nvme0n1p3      # Root partition
HOME_PART=/dev/nvme0n1p4      # Home partition

# Format partitions
mkfs.fat -F32 $EFI_PART           # Format EFI as FAT32
mkswap $SWAP_PART                 # Format swap
mkfs.ext4 $ROOT_PART              # Format root as ext4
mkfs.ext4 $HOME_PART              # Format home as ext4

# Mount partitions
mount $ROOT_PART /mnt                   # Mount root
mkdir /mnt/boot                         # Make boot dir
mount $EFI_PART /mnt/boot               # Mount EFI
mkdir /mnt/home                         # Make home dir
mount $HOME_PART /mnt/home              # Mount home
swapon $SWAP_PART                       # Enable swap

# Install base system + Intel GPU + dev tools
pacstrap /mnt base base-devel linux linux-firmware grub efibootmgr sudo networkmanager \
         xf86-video-intel mesa pulseaudio pavucontrol tlp git vlc firefox \
         vim network-manager-applet pipewire

# Generate fstab
genfstab -U /mnt >> /mnt/etc/fstab

# Chroot and configure system
arch-chroot /mnt /bin/bash <<EOF

# Set timezone
ln -sf /usr/share/zoneinfo/Canada/Eastern /etc/localtime
hwclock --systohc

# Locale setup
echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf

# Set hostname
echo "archbook" > /etc/hostname

# Enable sudo for wheel group
echo "%wheel ALL=(ALL:ALL) ALL" | EDITOR=tee visudo

# Create user
useradd -m -G wheel -s /bin/bash $USERNAME
echo "$USERNAME:$PASSWORD" | chpasswd
usermod -aG audio,video,plugdev $USERNAME  # Add user to important groups

# Enable network
systemctl enable NetworkManager

# Enable system services
systemctl enable systemd-timesyncd
systemctl enable ufw

# Kernel parameters (optional, add custom parameters here)
echo 'GRUB_CMDLINE_LINUX_DEFAULT="quiet splash"' >> /etc/default/grub

# Install GRUB to EFI
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
grub-mkconfig -o /boot/grub/grub.cfg

# Optimize swap settings (Optional)
echo "vm.swappiness=10" > /etc/sysctl.d/99-sysctl.conf

# Enable power management tools
systemctl enable tlp

EOF

# Done
echo "System installed with basic configurations and necessary drivers. Now chroot to add users, setup GUI, and finish config."
