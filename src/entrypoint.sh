#!/bin/bash -e

# Enable debug mode if requested
if [ "${DEBUG}" == "true" ]; then
  set -x
fi

# Augeas base path for Avahi configuration
AUG_BASE="/files/etc/avahi/avahi-daemon.conf"

# Function to set Avahi configuration using Augeas
avahi_set() {
  if [ $# -lt 3 ]; then
    >&2 echo "Usage: avahi_set SECTION KEY VALUE"
    return 1
  fi
  echo "Setting Avahi config: $1/$2=$3"
  augtool set "${AUG_BASE}/$1/$2" "$3"
}

# Default configurations
SERVER_ENABLE_DBUS=${SERVER_ENABLE_DBUS:-no}

# Read and log all environment variables related to Avahi
for var in $(env | grep -E '^SERVER_|^WIDE_AREA_|^PUBLISH_|^REFLECTOR_|^RLIMITS_'); do
  echo "Docker Config Variable: $var"
done

# Configure server section
if [ -n "${SERVER_HOST_NAME}" ]; then
  avahi_set "server" "host-name" "${SERVER_HOST_NAME}"
fi
if [ -n "${SERVER_DOMAIN_NAME}" ]; then
  avahi_set "server" "domain-name" "${SERVER_DOMAIN_NAME}"
fi
if [ -n "${SERVER_BROWSE_DOMAINS}" ]; then
  avahi_set "server" "browse-domains" "${SERVER_BROWSE_DOMAINS}"
fi
if [ -n "${SERVER_USE_IPV4}" ]; then
  avahi_set "server" "use-ipv4" "${SERVER_USE_IPV4}"
fi
if [ -n "${SERVER_USE_IPV6}" ]; then
  avahi_set "server" "use-ipv6" "${SERVER_USE_IPV6}"
fi
if [ -n "${SERVER_ALLOW_INTERFACES}" ]; then
  avahi_set "server" "allow-interfaces" "${SERVER_ALLOW_INTERFACES}"
fi
if [ -n "${SERVER_DENY_INTERFACES}" ]; then
  avahi_set "server" "deny-interfaces" "${SERVER_DENY_INTERFACES}"
fi
if [ -n "${SERVER_CHECK_RESPONSE_TTL}" ]; then
  avahi_set "server" "check-response-ttl" "${SERVER_CHECK_RESPONSE_TTL}"
fi
if [ -n "${SERVER_USE_IFF_RUNNING}" ]; then
  avahi_set "server" "use-iff-running" "${SERVER_USE_IFF_RUNNING}"
fi
if [ -n "${SERVER_ENABLE_DBUS}" ]; then
  avahi_set "server" "enable-dbus" "${SERVER_ENABLE_DBUS}"
fi
if [ -n "${SERVER_DISALLOW_OTHER_STACKS}" ]; then
  avahi_set "server" "disallow-other-stacks" "${SERVER_DISALLOW_OTHER_STACKS}"
fi
if [ -n "${SERVER_ALLOW_POINT_TO_POINT}" ]; then
  avahi_set "server" "allow-point-to-point" "${SERVER_ALLOW_POINT_TO_POINT}"
fi

# Configure wide-area section
if [ -n "${WIDE_AREA_ENABLE_WIDE_AREA}" ]; then
  avahi_set "wide-area" "enable-wide-area" "${WIDE_AREA_ENABLE_WIDE_AREA}"
fi

# Configure publish section
if [ -n "${PUBLISH_DISABLE_PUBLISHING}" ]; then
  avahi_set "publish" "disable-publishing" "${PUBLISH_DISABLE_PUBLISHING}"
fi
if [ -n "${PUBLISH_PUBLISH_ADDRESSES}" ]; then
  avahi_set "publish" "publish-addresses" "${PUBLISH_PUBLISH_ADDRESSES}"
fi
if [ -n "${PUBLISH_PUBLISH_HINFO}" ]; then
  avahi_set "publish" "publish-hinfo" "${PUBLISH_PUBLISH_HINFO}"
fi
if [ -n "${PUBLISH_PUBLISH_WORKSTATION}" ]; then
  avahi_set "publish" "publish-workstation" "${PUBLISH_PUBLISH_WORKSTATION}"
fi

# Configure reflector section
if [ -n "${REFLECTOR_ENABLE_REFLECTOR}" ]; then
  avahi_set "reflector" "enable-reflector" "${REFLECTOR_ENABLE_REFLECTOR}"
fi
if [ -n "${REFLECTOR_REFLECT_IPV}" ]; then
  avahi_set "reflector" "reflect-ipv" "${REFLECTOR_REFLECT_IPV}"
fi

# Configure rlimits section
if [ -n "${RLIMITS_RLIMIT_AS}" ]; then
  avahi_set "rlimits" "rlimit-as" "${RLIMITS_RLIMIT_AS}"
fi
if [ -n "${RLIMITS_RLIMIT_CORE}" ]; then
  avahi_set "rlimits" "rlimit-core" "${RLIMITS_RLIMIT_CORE}"
fi
if [ -n "${RLIMITS_RLIMIT_DATA}" ]; then
  avahi_set "rlimits" "rlimit-data" "${RLIMITS_RLIMIT_DATA}"
fi
if [ -n "${RLIMITS_RLIMIT_FSIZE}" ]; then
  avahi_set "rlimits" "rlimit-fsize" "${RLIMITS_RLIMIT_FSIZE}"
fi
if [ -n "${RLIMITS_RLIMIT_NOFILE}" ]; then
  avahi_set "rlimits" "rlimit-nofile" "${RLIMITS_RLIMIT_NOFILE}"
fi
if [ -n "${RLIMITS_RLIMIT_STACK}" ]; then
  avahi_set "rlimits" "rlimit-stack" "${RLIMITS_RLIMIT_STACK}"
fi
if [ -n "${RLIMITS_RLIMIT_NPROC}" ]; then
  avahi_set "rlimits" "rlimit-nproc" "${RLIMITS_RLIMIT_NPROC}"
fi

# Cleanup stale PID file if necessary
PID_FILE="/var/run/avahi-daemon/pid"
if [ -f "${PID_FILE}" ]; then
  AVAHI_PID=$(cat "${PID_FILE}")
  if [ -z "${AVAHI_PID}" ] || ! kill -0 "${AVAHI_PID}" 2>/dev/null; then
    >&2 echo "Cleaning up stale PID file: ${PID_FILE}"
    rm -f "${PID_FILE}"
  fi
fi

# Execute provided command or run avahi-daemon by default
if [ $# -eq 0 ] || [[ "$1" == -* ]]; then
  exec avahi-daemon "$@"
else
  exec "$@"
fi
