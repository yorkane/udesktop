FROM gezp/ubuntu-desktop:24.04

# Install rclone and fuse for S3 mounting
RUN apt-get update && apt-get install -y \
    rclone \
    fuse3 \
    curl \
    gnupg \
    && rm -rf /var/lib/apt/lists/*

# Install Node.js 22 from Chinese mirror (npmmirror)
RUN curl -fsSL https://registry.npmmirror.com/-/binary/node/v22.22.0/node-v22.22.0-linux-x64.tar.xz -o /tmp/node.tar.xz \
    && tar -xJf /tmp/node.tar.xz -C /usr/local --strip-components=1 \
    && rm /tmp/node.tar.xz \
    && node --version && npm --version \
    && npm install -g nrm \
    && nrm use taobao \
    && npm install -g midscene-pc@latest

# Install Google Chrome from Chinese mirror
RUN curl -fsSL https://registry.npmmirror.com/-/binary/chrome-for-testing/146.0.7651.0/linux64/chrome-linux64.zip -o /tmp/chrome.zip \
    && apt-get update && apt-get install -y unzip libxss1 libappindicator3-1 libasound2t64 libatk-bridge2.0-0 libgtk-3-0 libgbm1 libnss3 \
    && unzip /tmp/chrome.zip -d /opt/ \
    && ln -sf /opt/chrome-linux64/chrome /usr/local/bin/chrome \
    && rm /tmp/chrome.zip \
    && rm -rf /var/lib/apt/lists/*

# Install midscene-pc dependencies (WebKitGTK 4.1 with symlinks for 4.0 compatibility)
RUN apt-get update && apt-get install -y libwebkit2gtk-4.1-0 \
    && ln -sf /usr/lib/x86_64-linux-gnu/libwebkit2gtk-4.1.so.0 /usr/lib/x86_64-linux-gnu/libwebkit2gtk-4.0.so.37 \
    && ln -sf /usr/lib/x86_64-linux-gnu/libjavascriptcoregtk-4.1.so.0 /usr/lib/x86_64-linux-gnu/libjavascriptcoregtk-4.0.so.18 \
    && ldconfig \
    && rm -rf /var/lib/apt/lists/*


# Install Chrome Icon
RUN if [ -f /opt/chrome-linux64/product_logo_256.png ]; then \
        cp /opt/chrome-linux64/product_logo_256.png /usr/share/pixmaps/google-chrome.png; \
    elif [ -f /opt/chrome-linux64/product_logo_48.png ]; then \
        cp /opt/chrome-linux64/product_logo_48.png /usr/share/pixmaps/google-chrome.png; \
    else \
        curl -fsSL https://upload.wikimedia.org/wikipedia/commons/e/e1/Google_Chrome_icon_%28February_2022%29.svg -o /usr/share/pixmaps/google-chrome.svg; \
    fi

# Create Chrome desktop shortcut
RUN mkdir -p /etc/skel/Desktop && \
    echo '[Desktop Entry]\n\
Version=1.0\n\
Type=Application\n\
Name=Google Chrome\n\
Comment=Access the Internet\n\
Exec=/usr/local/bin/chrome --no-sandbox --disable-dev-shm-usage --start-maximized --test-type --no-first-run --no-default-browser-check --disable-search-engine-choice-screen --disable-infobars --password-store=basic %U\n\
Icon=google-chrome\n\
Terminal=false\n\
Categories=Network;WebBrowser;' > /etc/skel/Desktop/chrome.desktop && \
    chmod +x /etc/skel/Desktop/chrome.desktop

# Add custom kasmvnc startup script with reduced logging and resolution support
COPY start_kasmvnc.sh /docker_config/start_kasmvnc.sh
RUN chmod +x /docker_config/start_kasmvnc.sh

# Add custom_env_init hook script (runs after user creation)
COPY custom_env_init.sh /docker_config/custom_env_init.sh
RUN chmod +x /docker_config/custom_env_init.sh

# Add startup script
COPY start.sh /start.sh
RUN chmod +x /start.sh

# Set entrypoint
ENTRYPOINT ["/start.sh"]
