#!/bin/bash -e

# Enable debug mode if requested
if [ "${DEBUG}" = "true" ]; then
  set -x
fi

AUG_BASE="/files/etc/avahi/avahi-daemon.conf"

avahi_set() {
  if [ $# -lt 3 ]; then
    >&2 echo "Usage: avahi_set SECTION KEY VALUE"
    return 1
  fi
  augtool set "${AUG_BASE}/$1/$2" "$3"
}

# Default settings
SERVER_ENABLE_DBUS=${SERVER_ENABLE_DBUS:-no}

# Apply configurations based on environment variables
apply_config() {
  local section=$1
  local key=$2
  local value=$3
  [ -n "$value" ] && avahi_set "$section" "$key" "$value"
}

# Server configuration
apply_config "server" "host-name" "$SERVER_HOST_NAME"
apply_config "server" "domain-name" "$SERVER_DOMAIN_NAME"
apply_config "server" "browse-domains" "$SERVER_BROWSE_DOMAINS"
apply_config "server" "use-ipv4" "$SERVER_USE_IPV4"
apply_config "server" "use-ipv6" "$SERVER_USE_IPV6"
apply_config "server" "allow-interfaces" "$SERVER_ALLOW_INTERFACES"
apply_config "server" "deny-interfaces" "$SERVER_DENY_INTERFACES"
apply_config "server" "check-response-ttl" "$SERVER_CHECK_RESPONSE_TTL"
apply_config "server" "use-iff-running" "$SERVER_USE_IFF_RUNNING"
apply_config "server" "enable-dbus" "$SERVER_ENABLE_DBUS"
apply_config "server" "disallow-other-stacks" "$SERVER_DISALLOW_OTHER_STACKS"
apply_config "server" "allow-point-to-point" "$SERVER_ALLOW_POINT_TO_POINT"
apply_config "server" "cache-entries-max" "$SERVER_CACHE_ENTRIES_MAX"
apply_config "server" "clients-max" "$SERVER_CLIENTS_MAX"
apply_config "server" "objects-per-client-max" "$SERVER_OBJECTS_PER_CLIENT_MAX"
apply_config "server" "entries-per-entry-group-max" "$SERVER_ENTRIES_PER_ENTRY_GROUP_MAX"
apply_config "server" "ratelimit-interval-usec" "$SERVER_RATELIMIT_INTERVAL_USEC"
apply_config "server" "ratelimit-burst" "$SERVER_RATELIMIT_BURST"

# Wide-area configuration
apply_config "wide-area" "enable-wide-area" "$WIDE_AREA_ENABLE_WIDE_AREA"

# Publish configuration
apply_config "publish" "disable-publishing" "$PUBLISH_DISABLE_PUBLISHING"
apply_config "publish" "disable-user-service-publishing" "$PUBLISH_DISABLE_USER_SERVICE_PUBLISHING"
apply_config "publish" "add-service-cookie" "$PUBLISH_ADD_SERVICE_COOKIE"
apply_config "publish" "publish-addresses" "$PUBLISH_PUBLISH_ADDRESSES"
apply_config "publish" "publish-hinfo" "$PUBLISH_PUBLISH_HINFO"
apply_config "publish" "publish-workstation" "$PUBLISH_PUBLISH_WORKSTATION"
apply_config "publish" "publish-domain" "$PUBLISH_PUBLISH_DOMAIN"
apply_config "publish" "publish-dns-servers" "$PUBLISH_PUBLISH_DNS_SERVERS"
apply_config "publish" "publish-resolv-conf-dns-servers" "$PUBLISH_PUBLISH_RESOLV_CONF_DNS_SERVERS"
apply_config "publish" "publish-aaaa-on-ipv4" "$PUBLISH_PUBLISH_AAAA_ON_IPV4"
apply_config "publish" "publish-a-on-ipv6" "$PUBLISH_PUBLISH_A_ON_IPV6"

# Reflector configuration
apply_config "reflector" "enable-reflector" "$REFLECTOR_ENABLE_REFLECTOR"
apply_config "reflector" "reflect-ipv" "$REFLECTOR_REFLECT_IPV"
apply_config "reflector" "reflect-filters" "$REFLECTOR_REFLECT_FILTERS"

# RLimits configuration
for limit in RLIMIT_AS RLIMIT_CORE RLIMIT_DATA RLIMIT_FSIZE RLIMIT_NOFILE RLIMIT_STACK RLIMIT_NPROC; do
  apply_config "rlimits" "${limit,,}" "${!limit}"
done

# Cleanup PID file if stale
PID_FILE=/var/run/avahi-daemon/pid
if [ -f "$PID_FILE" ]; then
  AVAHI_PID=$(cat "$PID_FILE")
  echo "Found PID file ($PID_FILE) with PID $AVAHI_PID"
  if [ -z "$AVAHI_PID" ] || ! kill -0 "$AVAHI_PID" 2>/dev/null; then
    echo "Stale PID file detected, cleaning up"
    rm -v "$PID_FILE"
  fi
fi

# Start services
echo "Starting dbus..."
dbus-daemon --system

echo "Starting avahi-daemon..."
avahi-daemon --no-chroot

# Execute provided command if available
if [ $# -eq 0 ] || [[ "$1" == -* ]]; then
  exec avahi-daemon "$@"
else
  exec "$@"
fi
