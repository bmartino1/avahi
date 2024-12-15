# Use GUI-enabled base image for both build and final stages
FROM jlesage/baseimage-gui:debian-12-v4.6.4 AS build

# Install dependencies for building from source and necessary Debian packages
RUN apt-get update && apt-get install -y \
    git \
    build-essential \
    autoconf \
    automake \
    libtool \
    pkg-config \
    dbus \
    libavahi-client-dev \
    libavahi-core-dev \
    libgtk-3-dev \
    libdbus-1-dev \
    libssl-dev \
    avahi-daemon \
    libnss-mdns \
    avahi-utils \
    mdns-scan \
    avahi-discover \
    avahi-dnsconfd \
    avahi-browse \
    avahi-publish \
    avahi-resolve \
    avahi-set-host-name \
    avahi-ui-utils \
    augeas-tools \
    curl && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# Clone and build Avahi from source
WORKDIR /usr/src
RUN git clone https://github.com/avahi/avahi.git && \
    cd avahi && \
    ./autogen.sh && \
    ./configure --enable-gtk3 --prefix=/usr && \
    make && make install

# Use GUI-enabled base image for final stage
FROM jlesage/baseimage-gui:debian-12-v4.6.4

# Copy built files from the previous stage
COPY --from=build /usr /usr
COPY --from=build /etc /etc
COPY --from=build /lib /lib
COPY --from=build /opt /opt

# Copy and configure entrypoint script
COPY entrypoint.sh /opt/entrypoint.sh
RUN chmod +x /opt/entrypoint.sh

# Set environment variables
ENV APP_NAME="AvahiGUI"

# Expose Avahi port (mDNS uses port 5353/udp)
EXPOSE 5353/udp

# Create startapp.sh to launch Avahi UI
RUN echo '#!/bin/bash\nset -e\nexec avahi-discover' > /startapp.sh && chmod +x /startapp.sh

# Define entrypoint
ENTRYPOINT ["/bin/bash", "/opt/entrypoint.sh"]

# Start the Avahi UI
CMD ["/startapp.sh"]
