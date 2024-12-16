#!/bin/bash -e

# Enable debug mode if requested
if [ "${DEBUG}" == "true" ]; then
  set -x
fi

# Backup original configuration file
CONFIG_FILE="/etc/avahi/avahi-daemon.conf"
BACKUP_FILE="/etc/avahi/avahi-daemon.conf.bak"
if [ ! -f "${BACKUP_FILE}" ]; then
  cp "${CONFIG_FILE}" "${BACKUP_FILE}"
fi

# Ensure Augeas working directory exists
mkdir -p /files/etc/avahi

# Augeas base path for Avahi configuration
AUG_BASE="/files/etc/avahi/avahi-daemon.conf"

# Function to set Avahi configuration using Augeas
avahi_set() {
  if [ $# -lt 3 ]; then
    >&2 echo "Usage: avahi_set SECTION KEY VALUE"
    return 1
  fi
  echo "Setting Avahi config: $1/$2=$3"
  augtool set "${AUG_BASE}/$1/$2" "$3" || echo "Failed to set $1/$2"
}

# Stop Avahi Daemon if running
if pgrep avahi-daemon >/dev/null; then
  echo "Stopping running Avahi Daemon..."
  pkill avahi-daemon
  sleep 2
fi

# Read and log all environment variables related to Avahi
for var in $(env | grep -E '^SERVER_|^WIDE_AREA_|^PUBLISH_|^REFLECTOR_|^RLIMITS_'); do
  echo "Docker Config Variable: $var"
done

# Apply Avahi Configuration Sections
apply_config() {
  SECTION=$1
  declare -A CONFIGS=(${!2})
  for KEY in "${!CONFIGS[@]}"; do
    avahi_set "$SECTION" "$KEY" "${CONFIGS[$KEY]}"
  done
}

# Define Configuration Mappings
declare -A SERVER_CONFIGS=(
  ["host-name"]="${SERVER_HOST_NAME}"
  ["domain-name"]="${SERVER_DOMAIN_NAME}"
  ["browse-domains"]="${SERVER_BROWSE_DOMAINS}"
  ["use-ipv4"]="${SERVER_USE_IPV4}"
  ["use-ipv6"]="${SERVER_USE_IPV6}"
  ["allow-interfaces"]="${SERVER_ALLOW_INTERFACES}"
  ["deny-interfaces"]="${SERVER_DENY_INTERFACES}"
  ["enable-dbus"]="${SERVER_ENABLE_DBUS}"
  ["disallow-other-stacks"]="${SERVER_DISALLOW_OTHER_STACKS}"
  ["allow-point-to-point"]="${SERVER_ALLOW_POINT_TO_POINT}"
)

apply_config "server" SERVER_CONFIGS[@]

declare -A WIDE_AREA_CONFIGS=(
  ["enable-wide-area"]="${WIDE_AREA_ENABLE_WIDE_AREA}"
)
apply_config "wide-area" WIDE_AREA_CONFIGS[@]

declare -A PUBLISH_CONFIGS=(
  ["disable-publishing"]="${PUBLISH_DISABLE_PUBLISHING}"
  ["publish-addresses"]="${PUBLISH_PUBLISH_ADDRESSES}"
  ["publish-hinfo"]="${PUBLISH_PUBLISH_HINFO}"
  ["publish-workstation"]="${PUBLISH_PUBLISH_WORKSTATION}"
)
apply_config "publish" PUBLISH_CONFIGS[@]

declare -A REFLECTOR_CONFIGS=(
  ["enable-reflector"]="${REFLECTOR_ENABLE_REFLECTOR}"
  ["reflect-ipv"]="${REFLECTOR_REFLECT_IPV}"
)
apply_config "reflector" REFLECTOR_CONFIGS[@]

declare -A RLIMITS_CONFIGS=(
  ["rlimit-as"]="${RLIMITS_RLIMIT_AS}"
  ["rlimit-core"]="${RLIMITS_RLIMIT_CORE}"
  ["rlimit-data"]="${RLIMITS_RLIMIT_DATA}"
  ["rlimit-fsize"]="${RLIMITS_RLIMIT_FSIZE}"
  ["rlimit-nofile"]="${RLIMITS_RLIMIT_NOFILE}"
  ["rlimit-stack"]="${RLIMITS_RLIMIT_STACK}"
  ["rlimit-nproc"]="${RLIMITS_RLIMIT_NPROC}"
)
apply_config "rlimits" RLIMITS_CONFIGS[@]

# Save and Verify Configuration
echo "Saving Avahi Configuration..."
augtool save || echo "Failed to save configuration"

echo "Verifying Applied Config:"
augtool print "${AUG_BASE}" || echo "Failed to print configuration"

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
if [ $# -eq 0 ] || [[ "$1" == -* ]]; then
  exec avahi-daemon "$@"
else
  exec "$@"
fi
