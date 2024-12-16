#!/bin/bash -e

# Enable debug mode if requested
if [ "${DEBUG}" == "true" ]; then
  set -x
fi

# Configuration file paths
CONFIG_FILE="/etc/avahi/avahi-daemon.conf"
AUG_BASE="/files/etc/avahi/avahi-daemon.conf"

# Ensure configuration files exist
if [ ! -f "${CONFIG_FILE}" ]; then
  echo "Configuration file missing. Creating default configuration file."
  touch "${CONFIG_FILE}" && echo "Created: ${CONFIG_FILE}" || echo "Failed to create ${CONFIG_FILE}"
fi

if [ ! -f "${AUG_BASE}" ]; then
  echo "Augeas configuration path missing. Creating default Augeas path."
  mkdir -p $(dirname "${AUG_BASE}") && touch "${AUG_BASE}" && echo "Created: ${AUG_BASE}" || echo "Failed to create ${AUG_BASE}"
fi

# Ensure D-Bus is running
DBUS_PID_FILE="/run/dbus/pid"
if [ -f "${DBUS_PID_FILE}" ]; then
  DBUS_PID=$(cat "${DBUS_PID_FILE}")
  if [ -z "${DBUS_PID}" ] || ! kill -0 "${DBUS_PID}" 2>/dev/null; then
    echo "Cleaning up stale D-Bus PID file."
    rm -f "${DBUS_PID_FILE}"
  fi
fi

# Start D-Bus if not already running
if ! pgrep -x "dbus-daemon" >/dev/null; then
  echo "Starting D-Bus service..."
  mkdir -p /run/dbus && chmod 755 /run/dbus
  dbus-daemon --system --address=unix:path=/run/dbus/system_bus_socket &
  export DBUS_SYSTEM_BUS_ADDRESS=unix:path=/run/dbus/system_bus_socket
fi

# Stop Avahi Daemon if running
if pgrep avahi-daemon >/dev/null; then
  echo "Stopping running Avahi Daemon..."
  pkill avahi-daemon
  sleep 2
fi

# Function to set Avahi configuration using Augeas
avahi_set() {
  if [ $# -lt 3 ]; then
    >&2 echo "Usage: avahi_set SECTION KEY VALUE"
    return 1
  fi
  echo "Setting Avahi config: $1/$2=$3"
  augtool set "${AUG_BASE}/$1/$2" "$3" || echo "Failed to set $1/$2"
}

# Read and log all environment variables related to Avahi
for var in $(env | grep -E '^SERVER_|^WIDE_AREA_|^PUBLISH_|^REFLECTOR_|^RLIMITS_'); do
  echo "Docker Config Variable: $var"
  export "$var"
done

# Apply Avahi Configuration Sections
apply_config() {
  SECTION=$1
  declare -n CONFIGS=$2
  for KEY in "${!CONFIGS[@]}"; do
    VALUE=${CONFIGS[$KEY]}
    if [ -n "$VALUE" ]; then
      echo "Applying config $SECTION/$KEY=$VALUE"
      avahi_set "$SECTION" "$KEY" "$VALUE"
    fi
  done
}

# Define and Apply Configuration Mappings

declare -A SERVER_CONFIGS=(
  ["host-name"]="${SERVER_HOST_NAME}"
  ["domain-name"]="${SERVER_DOMAIN_NAME}"
  ["browse-domains"]="${SERVER_BROWSE_DOMAINS}"
  ["use-ipv4"]="${SERVER_USE_IPV4}"
  ["use-ipv6"]="${SERVER_USE_IPV6}"
  ["allow-interfaces"]="${SERVER_ALLOW_INTERFACES}"
  ["deny-interfaces"]="${SERVER_DENY_INTERFACES}"
  ["check-response-ttl"]="${SERVER_CHECK_RESPONSE_TTL}"
  ["use-iff-running"]="${SERVER_USE_IFF_RUNNING}"
  ["enable-dbus"]="${SERVER_ENABLE_DBUS}"
  ["disallow-other-stacks"]="${SERVER_DISALLOW_OTHER_STACKS}"
  ["allow-point-to-point"]="${SERVER_ALLOW_POINT_TO_POINT}"
)
apply_config "server" SERVER_CONFIGS

declare -A WIDE_AREA_CONFIGS=(
  ["enable-wide-area"]="${WIDE_AREA_ENABLE_WIDE_AREA}"
)
apply_config "wide-area" WIDE_AREA_CONFIGS

declare -A PUBLISH_CONFIGS=(
  ["disable-publishing"]="${PUBLISH_DISABLE_PUBLISHING}"
  ["publish-addresses"]="${PUBLISH_PUBLISH_ADDRESSES}"
  ["publish-hinfo"]="${PUBLISH_PUBLISH_HINFO}"
  ["publish-workstation"]="${PUBLISH_PUBLISH_WORKSTATION}"
)
apply_config "publish" PUBLISH_CONFIGS

declare -A REFLECTOR_CONFIGS=(
  ["enable-reflector"]="${REFLECTOR_ENABLE_REFLECTOR}"
  ["reflect-ipv"]="${REFLECTOR_REFLECT_IPV}"
  ["reflect-filters"]="${REFLECTOR_REFLECT_FILTERS}"
)
apply_config "reflector" REFLECTOR_CONFIGS

declare -A RLIMITS_CONFIGS=(
  ["rlimit-as"]="${RLIMITS_RLIMIT_AS}"
  ["rlimit-core"]="${RLIMITS_RLIMIT_CORE}"
  ["rlimit-data"]="${RLIMITS_RLIMIT_DATA}"
  ["rlimit-fsize"]="${RLIMITS_RLIMIT_FSIZE}"
  ["rlimit-nofile"]="${RLIMITS_RLIMIT_NOFILE}"
  ["rlimit-stack"]="${RLIMITS_RLIMIT_STACK}"
  ["rlimit-nproc"]="${RLIMITS_RLIMIT_NPROC}"
)
apply_config "rlimits" RLIMITS_CONFIGS

# Save and replace configuration
echo "Saving and applying Avahi configuration..."
augtool save || echo "Failed to save configuration"

# Replace the config file
cp "${AUG_BASE}" "${CONFIG_FILE}" && echo "Copied ${AUG_BASE} to ${CONFIG_FILE}" || echo "Failed to copy configuration"
chmod 644 "${CONFIG_FILE}" || echo "Failed to set permissions for ${CONFIG_FILE}"

# Check the configuration file
echo "Checking Config File Contents:"
cat "${CONFIG_FILE}" || echo "Failed to read configuration file"

# Cleanup stale PID file if necessary
PID_FILE="/var/run/avahi-daemon/pid"
if [ -f "${PID_FILE}" ]; then
  AVAHI_PID=$(cat "${PID_FILE}")
  if [ -z "${AVAHI_PID}" ] || ! kill -0 "${AVAHI_PID}" 2>/dev/null; then
    echo "Cleaning up stale PID file: ${PID_FILE}"
    rm -f "${PID_FILE}"
  fi
fi

# Execute provided command or run avahi-daemon by default
if [ -n "$(env | grep -E '^SERVER_|^WIDE_AREA_|^PUBLISH_|^REFLECTOR_|^RLIMITS_')" ]; then
  echo "Avahi Daemon started with Docker environment variables."
else
  echo "No Docker variables detected. Starting with default configuration."
fi

exec avahi-daemon --no-drop-root --debug "$@" &
AVAHI_PID=$!
if kill -0 "${AVAHI_PID}" 2>/dev/null; then
  echo "Avahi Daemon started successfully with PID ${AVAHI_PID}."
else
  echo "Failed to start Avahi Daemon."
fi
wait "${AVAHI_PID}"
