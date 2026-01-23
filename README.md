# JunctionRelay XSD - Raspberry Pi

One-command installer for JunctionRelay XSD on Raspberry Pi.

## Quick Install

Flash standard Raspberry Pi OS (64-bit Desktop), then run:

```bash
curl -fsSL https://raw.githubusercontent.com/catapultcase/JunctionRelay_XSD_Pi/main/install.sh | sudo bash
```

That's it! JunctionRelay will auto-open Firefox to the WebUI on boot.

## What This Does

- Downloads latest JunctionRelay AppImage
- Installs to `/opt/junctionrelay-xsd`
- Creates systemd service (auto-starts on boot)
- Auto-opens Firefox to WebUI on graphical session
- Works with any username you choose in Pi Imager
- No system dependencies required - everything is bundled!

## Requirements

- **Hardware:** Raspberry Pi 4 or Pi 5 (ARM64)
- **OS:** Raspberry Pi OS 64-bit Desktop (Bookworm or later)
- **Internet:** Required for installation
- **Disk Space:** ~300MB

## Setup Process

1. **Flash Pi OS** with [Raspberry Pi Imager](https://www.raspberrypi.com/software/)
   - Choose: Raspberry Pi OS (64-bit) **Desktop**
   - Customize: Username, WiFi, SSH (all optional)

2. **Boot your Pi** and run the install command above

3. **Access WebUI** at `http://localhost:8086/`

## Management Commands

```bash
# Check status
sudo systemctl status junctionrelay

# Restart service
sudo systemctl restart junctionrelay

# Stop service
sudo systemctl stop junctionrelay

# View logs
sudo journalctl -u junctionrelay -f

# Update to latest version
sudo /opt/junctionrelay-xsd/update.sh
```

## Updating

Update with a single command:

```bash
sudo /opt/junctionrelay-xsd/update.sh
```

The updater will:
- Check for latest release
- Download if newer version available
- Backup current AppImage
- Apply update
- Restart service

## Networking

**Default port:** `8086`

**Access from other devices:**
```
http://<pi-ip-address>:8086/
```

## Troubleshooting

### Service won't start

```bash
# Check logs
sudo journalctl -u junctionrelay -n 50

# Restart service
sudo systemctl restart junctionrelay
```

### WebUI not accessible

```bash
# Check if service is running
sudo systemctl status junctionrelay

# Check if port is in use
sudo ss -tlnp | grep 8086
```

### Firefox not opening

Firefox opens automatically when DISPLAY is available. If running headless, access the WebUI from another device on your network.

## Support

- **Issues:** [GitHub Issues](https://github.com/catapultcase/JunctionRelay_XSD_Pi/issues)
- **Main Repo:** [JunctionRelay XSD](https://github.com/catapultcase/JunctionRelay_XSD2)
