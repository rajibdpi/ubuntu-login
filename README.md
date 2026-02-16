# Ubuntu Login Fix

A comprehensive solution for fixing common Ubuntu login issues, including login loops, .Xauthority problems, and home directory permission issues.

## 🚨 Common Ubuntu Login Issues

This script addresses the following common login problems:

1. **Login Loop** - You enter your password correctly, but the screen goes black and returns to the login screen
2. **.Xauthority Issues** - Corrupted X authority files preventing GUI login
3. **Home Directory Permission Problems** - Incorrect ownership or permissions on home directory
4. **Temporary Profile** - System creating temporary profiles due to file access issues
5. **Display Manager Problems** - Issues with GDM3, LightDM, or SDDM configuration

## 📋 Prerequisites

- Ubuntu/Debian-based Linux distribution
- Root/sudo access
- Access to TTY console (Ctrl+Alt+F3)

## 🚀 Quick Start

### Direct Run From GitHub

Run the script directly without downloading a local file:

```bash
curl -fsSL https://raw.githubusercontent.com/rajibdpi/ubuntu-login/main/fix.sh | sudo bash
```

### From the Login Screen

If you're stuck at the login screen:

1. Press `Ctrl+Alt+F3` to access a text console
2. Login with your username and password
3. Run the fix script directly from GitHub:

```bash
# Run the script (will auto-detect your username)
curl -fsSL https://raw.githubusercontent.com/rajibdpi/ubuntu-login/main/fix.sh | sudo bash
```

### Manual Usage

If auto-detection picks the wrong user, set the target explicitly:

```bash
curl -fsSL https://raw.githubusercontent.com/rajibdpi/ubuntu-login/main/fix.sh | sudo bash -s -- --user username
```

Replace `username` with the actual username that has login issues.

### Optional: Reset GNOME User Config

If login issues are caused by broken GNOME user settings/extensions, run with:

```bash
curl -fsSL https://raw.githubusercontent.com/rajibdpi/ubuntu-login/main/fix.sh | sudo bash -s -- --reset-gnome
```

## 🔧 What the Script Does

The script performs the following fixes:

### 1. Auto-Detects Target User
- Uses `SUDO_USER` first
- Falls back to `logname`
- Final fallback is first regular local user (UID >= 1000)

### 2. Fixes `.Xauthority` and `.ICEauthority`
- Backs up existing files with timestamp suffix
- Removes broken authority files that can cause login loops

### 3. Repairs Ownership and PATH in User Shell Files
- Runs ownership repair on the user home directory
- Backs up `.profile`, `.bashrc`, `.bash_profile`, `.zprofile`, `.zshrc`
- Appends a safe PATH export to `.profile` and `.bashrc` if missing

### 4. Repairs Core Desktop/Login Packages
- Runs `apt-get update`
- Runs `apt-get -f install -y` and `dpkg --configure -a`
- Reinstalls `gdm3`, `gnome-shell`, `ubuntu-session`, and `xorg`
- Enables `gdm3`

### 5. Optional GNOME Profile Reset
- With `--reset-gnome`, backs up and resets:
  - `.config`
  - `.local/share`
  - `.cache`

### 6. Rewrites Global PATH in `/etc/environment`
- Backs up existing `/etc/environment`
- Rewrites it to:
  - `PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"`

## ⚠️ Safety Features

- Creates backups of all files before modification
- Validates target user and home directory before making changes
- Requires root privileges for safety
- Uses strict Bash mode (`set -euo pipefail`)

## 🔍 Troubleshooting

If the script doesn't resolve your issue, try these additional steps:

### 1. Check System Logs
```bash
journalctl -xe
```

### 2. Reconfigure Display Manager
```bash
# For GDM3
sudo dpkg-reconfigure gdm3

# For LightDM
sudo dpkg-reconfigure lightdm
```

### 3. Check for Disk Space Issues
```bash
df -h
```

If your disk is full, clean up space:
```bash
# Clean apt cache
sudo apt-get clean

# Remove old kernels
sudo apt-get autoremove
```

### 4. Verify Home Directory Permissions
```bash
ls -la /home/username
```

The home directory should be owned by the user with 755 permissions.

### 5. Check Authentication Logs
```bash
sudo tail -f /var/log/auth.log
```

### 6. Try Creating a New User
As a test, create a new user to see if the issue is system-wide:
```bash
sudo adduser testuser
```

## 🐛 Known Limitations

- The script must be run from a TTY console or SSH session, not from the GUI
- Requires sudo/root access
- Reinstalling packages requires network access to apt repositories
- The script rewrites `/etc/environment` PATH to a known-safe value

## 💡 Prevention Tips

To avoid login issues in the future:

1. **Regular Backups** - Keep backups of your home directory
2. **Monitor Disk Space** - Keep at least 10% free space
3. **Careful with Permissions** - Avoid using `sudo` with GUI applications
4. **Update Regularly** - Keep your system updated
5. **Graceful Shutdowns** - Always shutdown properly to avoid file corruption

## 🤝 Contributing

Contributions are welcome! Please feel free to submit issues or pull requests.

## 📄 License

This project is licensed under the GNU General Public License v3.0 - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

This script was created to help users resolve common Ubuntu login issues based on community solutions and best practices.

## ⚡ Emergency Recovery

If you cannot access TTY console:

1. Boot from Ubuntu Live USB
2. Mount your main partition
3. Chroot into your system
4. Run the fix script
5. Reboot

Example:
```bash
sudo mount /dev/sdaX /mnt
sudo mount --bind /dev /mnt/dev
sudo mount --bind /proc /mnt/proc
sudo mount --bind /sys /mnt/sys
sudo chroot /mnt
curl -fsSL https://raw.githubusercontent.com/rajibdpi/ubuntu-login/main/fix.sh | bash
exit
sudo reboot
```

Replace `/dev/sdaX` with your actual root partition.
