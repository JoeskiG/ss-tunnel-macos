#!/usr/bin/env bash
set -euo pipefail

CONFIG_FILE="tunnel.json"

if ! command -v jq >/dev/null 2>&1; then
    echo "Error: jq is required but not installed."
    exit 1
fi

if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "Error: $CONFIG_FILE does not exist."
    exit 1
fi

if ! jq empty "$CONFIG_FILE" >/dev/null 2>&1; then
    echo "Error: $CONFIG_FILE is not valid JSON."
    exit 1
fi

SERVER_COUNT=$(jq '.servers | length' "$CONFIG_FILE")

if [[ "$SERVER_COUNT" -eq 0 ]]; then
    echo "Error: No server addresses found in $CONFIG_FILE."
    exit 1
fi

GATEWAY=$(ipconfig getoption en0 router)

if [[ -z "$GATEWAY" ]]; then
    echo "Error: Failed to determine gateway for en0."
    exit 1
fi

# ---- tun2socks binary from config ----
TUN2SOCKS_BIN=$(jq -r '.tun2socks_binary_path // empty' "$CONFIG_FILE")

if [[ -z "$TUN2SOCKS_BIN" ]]; then
    echo "Error: tun2socks_binary_path missing in $CONFIG_FILE."
    exit 1
fi

if [[ ! -x "$TUN2SOCKS_BIN" ]]; then
    echo "Error: tun2socks binary not found or not executable at: $TUN2SOCKS_BIN"
    exit 1
fi

echo "Using tun2socks: $TUN2SOCKS_BIN"
echo "Using gateway: $GATEWAY"

resolve_host() {
    local input="$1"

    if [[ "$input" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        echo "$input"
        return
    fi

    local ip
    ip=$(dscacheutil -q host -a name "$input" 2>/dev/null | awk '/ip_address:/ {print $2; exit}')

    if [[ -n "$ip" ]]; then
        echo "$ip"
        return
    fi

    if command -v dig >/dev/null 2>&1; then
        ip=$(dig +short "$input" A | head -n 1)
        if [[ -n "$ip" ]]; then
            echo "$ip"
            return
        fi
    fi

    echo "Error: Could not resolve host: $input" >&2
    return 1
}

cleanup() {
    echo
    echo "Cleaning up routes..."

    sudo route delete -net 1.0.0.0/8 198.18.0.1 >/dev/null 2>&1 || true
    sudo route delete -net 2.0.0.0/7 198.18.0.1 >/dev/null 2>&1 || true
    sudo route delete -net 4.0.0.0/6 198.18.0.1 >/dev/null 2>&1 || true
    sudo route delete -net 8.0.0.0/5 198.18.0.1 >/dev/null 2>&1 || true
    sudo route delete -net 16.0.0.0/4 198.18.0.1 >/dev/null 2>&1 || true
    sudo route delete -net 32.0.0.0/3 198.18.0.1 >/dev/null 2>&1 || true
    sudo route delete -net 64.0.0.0/2 198.18.0.1 >/dev/null 2>&1 || true
    sudo route delete -net 128.0.0.0/1 198.18.0.1 >/dev/null 2>&1 || true

    while IFS= read -r address; do
        [[ -z "$address" ]] && continue

        ip=$(resolve_host "$address" || true)
        [[ -z "$ip" ]] && continue

        sudo route delete "$ip" "$GATEWAY" >/dev/null 2>&1 || true
    done < <(
        jq -r '.servers[]?.address // empty' "$CONFIG_FILE"
    )

    echo "Stopping tun2socks..."

    if kill -0 "$TUN2SOCKS_PID" 2>/dev/null; then
        kill "$TUN2SOCKS_PID"
        wait "$TUN2SOCKS_PID" 2>/dev/null || true
    fi
}

trap cleanup EXIT INT TERM

sudo "$TUN2SOCKS_BIN" \
    --device utun4 \
    --proxy socks5://localhost:1080 \
    --interface en0 &

TUN2SOCKS_PID=$!

for _ in $(seq 1 20); do
    if ifconfig utun4 >/dev/null 2>&1; then
        break
    fi
    sleep 0.5
done

if ! ifconfig utun4 >/dev/null 2>&1; then
    echo "Error: utun4 was not created by tun2socks."
    exit 1
fi

sudo ifconfig utun4 198.18.0.1 198.18.0.1 up

while IFS= read -r address; do
    [[ -z "$address" ]] && continue

    ip=$(resolve_host "$address")

    echo "Adding bypass route for $address -> $ip via $GATEWAY"
    sudo route add "$ip" "$GATEWAY"
done < <(
    jq -r '.servers[]?.address // empty' "$CONFIG_FILE"
)

sudo route add -net 1.0.0.0/8 198.18.0.1
sudo route add -net 2.0.0.0/7 198.18.0.1
sudo route add -net 4.0.0.0/6 198.18.0.1
sudo route add -net 8.0.0.0/5 198.18.0.1
sudo route add -net 16.0.0.0/4 198.18.0.1
sudo route add -net 32.0.0.0/3 198.18.0.1
sudo route add -net 64.0.0.0/2 198.18.0.1
sudo route add -net 128.0.0.0/1 198.18.0.1

echo "Tunnel is active. Press Ctrl+C to stop."

wait "$TUN2SOCKS_PID"