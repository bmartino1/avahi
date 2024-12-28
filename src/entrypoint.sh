#!/bin/bash -e

# Enable debug mode if requested
if [ "${DEBUG}" == "true" ]; then
  set -x
fi
#Docker Variable DEBUG value true

# Configuration file path in docker
CONFIG_FILE="/etc/avahi/avahi-daemon.conf"

# Ensure configuration file exists
if [ ! -f "${CONFIG_FILE}" ]; then
  echo "Configuration file missing. Creating a default configuration file."
  touch "${CONFIG_FILE}" && echo "Created: ${CONFIG_FILE}" || echo "Failed to create ${CONFIG_FILE}"
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

# Define Mapping Table for Docker Environment Variables
declare -A CONFIG_MAP=(
  ["SERVER_HOST_NAME"]="server/host-name"
  ["SERVER_DOMAIN_NAME"]="server/domain-name"
  ["SERVER_BROWSE_DOMAINS"]="server/browse-domains"
  ["SERVER_USE_IPV4"]="server/use-ipv4"
  ["SERVER_USE_IPV6"]="server/use-ipv6"
  ["SERVER_ALLOW_INTERFACES"]="server/allow-interfaces"
  ["SERVER_DENY_INTERFACES"]="server/deny-interfaces"
  ["SERVER_CHECK_RESPONSE_TTL"]="server/check-response-ttl"
  ["SERVER_USE_IFF_RUNNING"]="server/use-iff-running"
  ["SERVER_ENABLE_DBUS"]="server/enable-dbus"
  ["SERVER_DISALLOW_OTHER_STACKS"]="server/disallow-other-stacks"
  ["SERVER_ALLOW_POINT_TO_POINT"]="server/allow-point-to-point"
  ["WIDE_AREA_ENABLE_WIDE_AREA"]="wide-area/enable-wide-area"
  ["REFLECTOR_ENABLE_REFLECTOR"]="reflector/enable-reflector"
  ["REFLECTOR_REFLECT_IPV"]="reflector/reflect-ipv"
  ["PUBLISH_DISABLE_PUBLISHING"]="publish/disable-publishing"
  ["PUBLISH_DISABLE_USER_SERVICE_PUBLISHING"]="publish/disable-user-service-publishing"
  ["PUBLISH_ADD_SERVICE_COOKIE"]="publish/add-service-cookie"
  ["PUBLISH_PUBLISH_ADDRESSES"]="publish/publish-addresses"
  ["PUBLISH_PUBLISH_HINFO"]="publish/publish-hinfo"
  ["PUBLISH_PUBLISH_WORKSTATION"]="publish/publish-workstation"
  ["PUBLISH_PUBLISH_DOMAIN"]="publish/publish-domain"
  ["PUBLISH_PUBLISH_DNS_SERVERS"]="publish/publish-dns-servers"
  ["PUBLISH_PUBLISH_RESOLV_CONF_DNS_SERVERS"]="publish/resolv-conf-dns-servers"
  ["PUBLISH_PUBLISH_AAAA_ON_IPV4"]="publish/publish-aaaa-on-ipv4"
  ["PUBLISH_PUBLISH_A_ON_IPV6"]="publish/a-on-ipv6"
  ["RLIMITS_RLIMIT_AS"]="rlimits/rlimit-as"
  ["RLIMITS_RLIMIT_CORE"]="rlimits/rlimit-core"
  ["RLIMITS_RLIMIT_DATA"]="rlimits/rlimit-data"
  ["RLIMITS_RLIMIT_FSIZE"]="rlimits/rlimit-fsize"
  ["RLIMITS_RLIMIT_NOFILE"]="rlimits/rlimit-nofile"
  ["RLIMITS_RLIMIT_STACK"]="rlimits/rlimit-stack"
  ["RLIMITS_RLIMIT_NPROC"]="rlimits/rlimit-nproc"
)

# Create or Overwrite Config File
echo "# Docker Avahi Configuration" > "${CONFIG_FILE}"

declare -A SECTION_MAP

# Populate Config File from Docker Variables
echo "Generating Config File Reviewing Docker Variables"
for VAR in "${!CONFIG_MAP[@]}"; do
  CONFIG_KEY="${CONFIG_MAP[$VAR]}"
  SECTION="${CONFIG_KEY%%/*}"
  OPTION="${CONFIG_KEY#*/}"
  VALUE="${!VAR}"

  if [ -n "${VALUE}" ]; then
    SECTION_MAP["${SECTION}"]+="\n${OPTION}=${VALUE}"
  fi
done

# Write Config Sections to File
for SECTION in "${!SECTION_MAP[@]}"; do
  echo -e "[${SECTION}]\n${SECTION_MAP[${SECTION}]}" >> "${CONFIG_FILE}"
done

# Display Final Config Once
if [ -n "$(env | grep -E '^SERVER_|^WIDE_AREA_|^PUBLISH_|^REFLECTOR_|^RLIMITS_')" ]; then
  echo "Avahi Daemon started with Docker environment variables."
else
  echo "No Docker variables detected. Starting with default configuration."
fi

echo "--- Avahi Configuration File ---"
cat "${CONFIG_FILE}"

# Cleanup stale PID file if necessary
PID_FILE="/var/run/avahi-daemon/pid"
if [ -f "${PID_FILE}" ]; then
  AVAHI_PID=$(cat "${PID_FILE}")
  if [ -z "${AVAHI_PID}" ] || ! kill -0 "${AVAHI_PID}" 2>/dev/null; then
    echo "Cleaning up stale PID file: ${PID_FILE}"
    rm -f "${PID_FILE}"
  fi
fi

# Stop any existing Avahi daemon instances to prevent conflicts
if pgrep -x "avahi-daemon" >/dev/null; then
  echo "Stopping existing Avahi Daemon to prevent conflicts."
  pkill -x "avahi-daemon"
fi

# Execute provided command or run avahi-daemon by default
exec avahi-daemon --no-drop-root --debug &
AVAHI_PID=$!
if kill -0 "${AVAHI_PID}" 2>/dev/null; then
  echo "Avahi Daemon started successfully with PID ${AVAHI_PID}."
  wait "${AVAHI_PID}"
else
  echo "Failed to start Avahi Daemon. Exiting."
  exit 1
fi
