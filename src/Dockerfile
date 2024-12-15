FROM alpine

# Install necessary packages
RUN apk add --no-cache avahi augeas nss-mdns dbus avahi-tools

# Add the entrypoint script
ADD entrypoint.sh /opt/entrypoint.sh
RUN chmod +x /opt/entrypoint.sh

# Configure Generic nsswitch.conf for mDNS support
RUN echo "hosts: files mdns4_minimal [NOTFOUND=return] dns mdns4" > /etc/nsswitch.conf

# Enable Avahi services
RUN rc-update add dbus && rc-update add avahi-daemon

# Define entrypoint
ENTRYPOINT ["/opt/entrypoint.sh"]

