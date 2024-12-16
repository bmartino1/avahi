# Use Debian Slim as the base image
FROM debian:bookworm-slim

# Install locales package and set environment variables
RUN apt-get update && apt-get install -y locales && \
    echo "en_US.UTF-8 UTF-8" > /etc/locale.gen && \
    locale-gen en_US.UTF-8 && \
    update-locale LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8

# Set environment variables for locale
ENV LANG="en_US.UTF-8" \
    LANGUAGE="en_US:en" \
    LC_ALL="en_US.UTF-8"

# Install necessary Debian packages
RUN apt-get update && apt-get install -y \
    dbus \
    avahi-daemon \
    libnss-mdns \
    avahi-utils \
    mdns-scan \
    avahi-dnsconfd \
    augeas-tools \
    curl \
    which \
    dnsutils \
    iputils-ping \
    procps \
    psmisc && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# Configure D-Bus service
RUN mkdir -p /run/dbus && chmod 755 /run/dbus

# Expose Avahi port (mDNS uses port 5353/udp)
EXPOSE 5353/udp

# Copy and configure entrypoint script
COPY entrypoint.sh /opt/entrypoint.sh
RUN chmod +x /opt/entrypoint.sh

# Create startapp.sh to launch Avahi Daemon
RUN echo '#!/bin/bash\nset -e\n# Ensure correct D-Bus setup\nmkdir -p /run/dbus && chmod 755 /run/dbus\nif [ -f /run/dbus/pid ]; then rm -f /run/dbus/pid; fi\ndbus-daemon --system --address=unix:path=/run/dbus/system_bus_socket &\nsleep 2\nexport DBUS_SYSTEM_BUS_ADDRESS=unix:path=/run/dbus/system_bus_socket\n# Start Avahi Daemon\necho "Starting Avahi Daemon..."\navahi-daemon --no-drop-root --debug\n' > /startapp.sh && chmod +x /startapp.sh

# Set entrypoint and start the app
ENTRYPOINT ["/bin/bash", "/opt/entrypoint.sh"]
CMD ["/startapp.sh"]
