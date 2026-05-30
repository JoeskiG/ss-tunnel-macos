# Shadowsocks Tunnel for macOS

A tool to set up and manage Shadowsocks tunneling on macOS using TUN2SOCKS, enabling system-wide proxy capabilities for secure network traffic routing.

## Prerequisites

- macOS system
- `sudo` access for network configuration

## Installation & Setup

### 1. Download TUN2SOCKS Binary

Download the appropriate binary from [xjasonlyu's tun2socks releases](https://github.com/xjasonlyu/tun2socks/releases):

### 2. Configure tunnel.json

Create a file called `tunnel.json` with your proxy server addresses and the path to your TUN2SOCKS binary.

**Supported address formats:**

- Domain names (e.g., `proxy.example.com`)
- IPv4 addresses (e.g., `192.168.1.1`)

**Example configuration:**

```json
{
  "tun2socks_binary_path": "./tun2socks-darwin-arm64",
  "servers": [
    {
      "address": "proxy1.example.com"
    },
    {
      "address": "192.168.1.100"
    }
  ]
}
```

### 3. Make the Script Executable

```bash
chmod +x ./start_tunnel.sh
```

### 4. Start the Tunnel

```bash
sudo ./start_tunnel.sh
```

This will initialize the TUN interface and route traffic through your configured proxy servers.

### 5. Enable Proxy in Your Proxy Client

Use compatible proxy software such as **Shadowsocks-NG** and enable it to direct traffic through the tunnel:

- Launch Shadowsocks-NG (or your preferred proxy client)
- Enable/activate the proxy

## Troubleshooting

- **Permission Denied**: Ensure `start_tunnel.sh` has execute permissions (`chmod +x start_tunnel.sh`)
- **Binary Not Found**: Verify the `tun2socks_binary_path` in `tunnel.json` is correct
- **Network Issues**: Check that your proxy server addresses are reachable and correctly formatted
- **Requires Admin**: The script needs `sudo` to configure network interfaces

## Files

- `start_tunnel.sh` - Main tunnel initialization script
- `tunnel.json` - Configuration file for proxy servers and binary path
