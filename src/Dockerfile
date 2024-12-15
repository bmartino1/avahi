# Use Debian Slim as the base image
FROM debian:bookworm-slim

# Install required packages
RUN apt-get update && apt-get install -y \
    avahi-daemon \
    libnss-mdns \
    avahi-utils \
    dbus \
    bash \
    tzdata \
    augeas-tools && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# Configure nsswitch.conf for mDNS support
RUN echo "hosts: files mdns4_minimal [NOTFOUND=return] dns mdns4" > /etc/nsswitch.conf

# Add and fix permissions for the entrypoint script
ADD entrypoint.sh /opt/entrypoint.sh
RUN chmod +x /opt/entrypoint.sh

# Expose Avahi port (mDNS uses port 5353/udp)
EXPOSE 5353/udp

# Define entrypoint
ENTRYPOINT ["/bin/bash", "/opt/entrypoint.sh"]
