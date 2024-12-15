# Use latest Alpine Linux with glibc for compatibility
FROM frolvlad/alpine-glibc:latest

# Install necessary packages
RUN apk add --no-cache \
    avahi \
    augeas \
    dbus \
    avahi-tools \
    bash \
    tzdata

# Configure Generic nsswitch.conf for mDNS support (without nss-mdns)
RUN echo "hosts: files dns mdns4_minimal [NOTFOUND=return] mdns4" > /etc/nsswitch.conf

# Add the entrypoint script
ADD entrypoint.sh /opt/entrypoint.sh
RUN chmod +x /opt/entrypoint.sh

# Expose Avahi port (mDNS uses port 5353/udp)
EXPOSE 5353/udp

# Define entrypoint
ENTRYPOINT ["/opt/entrypoint.sh"]
