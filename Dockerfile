FROM gezp/ubuntu-desktop:24.04

ENV DISPLAY=:1000

# System dependencies (all apt installs merged into one layer)
RUN apt-get update && apt-get install -y --no-install-recommends \
    rclone fuse3 curl gnupg autocutsel xclip imagemagick git unzip jq gdebi \
    vlc file-roller \
    libxss1 libappindicator3-1 libasound2t64 libatk-bridge2.0-0 \
    libgtk-3-0 libgbm1 libnss3 python3-gi python3-gi-cairo \
    libwebkit2gtk-4.1-0 \
    && ln -sf /usr/lib/x86_64-linux-gnu/libwebkit2gtk-4.1.so.0 /usr/lib/x86_64-linux-gnu/libwebkit2gtk-4.0.so.37 \
    && ln -sf /usr/lib/x86_64-linux-gnu/libjavascriptcoregtk-4.1.so.0 /usr/lib/x86_64-linux-gnu/libjavascriptcoregtk-4.0.so.18 \
    && ldconfig \
    && rm -rf /var/lib/apt/lists/*

# Preload cached assets (cleaned at end of RUN to minimize layer size)
COPY preload/ /tmp/preload/

# Node.js + Chrome + Extensions (single RUN, all temp files cleaned within same layer)
RUN set -ex \
    # --- Node.js ---
    && NODE_TAR="node-v24.15.0-linux-x64.tar.xz" \
    && if [ -f /tmp/preload/$NODE_TAR ]; then echo "Using preloaded Node.js..."; cp /tmp/preload/$NODE_TAR /tmp/$NODE_TAR; \
    else curl -fsSL "https://registry.npmmirror.com/-/binary/node/v24.15.0/$NODE_TAR" -o /tmp/$NODE_TAR; fi \
    && tar -xJf /tmp/$NODE_TAR -C /usr/local --strip-components=1 \
    && rm -f /tmp/$NODE_TAR \
    && npm install -g nrm pnpm \
    && nrm use taobao \
    && npm cache clean --force \
    && node --version && npm --version \
    # --- SwitchyOmega ---
    && if [ -f /tmp/preload/switchy.zip ]; then cp /tmp/preload/switchy.zip /tmp/switchy.zip; \
    else wget -qO /tmp/switchy.zip "https://clients2.google.com/service/update2/crx?response=redirect&acceptformat=crx2,crx3&prodversion=114.0&x=id%3Dhihblcmlaaademjlakdpicchbjnnnkbo%26installsource%3Dondemand%26uc"; fi \
    && mkdir -p /opt/switchyomega \
    && (unzip -qo /tmp/switchy.zip -d /opt/switchyomega || true) \
    && rm -f /tmp/switchy.zip \
    # --- Midscene.js Extension ---
    && if [ -f /tmp/preload/midscene-ext.zip ]; then cp /tmp/preload/midscene-ext.zip /tmp/midscene-ext.zip; \
    else wget -qO /tmp/midscene-ext.zip "https://clients2.google.com/service/update2/crx?response=redirect&acceptformat=crx2,crx3&prodversion=114.0&x=id%3Dgbldofcpkknbggpkmbdaefngejllnief%26installsource%3Dondemand%26uc"; fi \
    && mkdir -p /opt/midscene-ext \
    && (unzip -qo /tmp/midscene-ext.zip -d /opt/midscene-ext || true) \
    && rm -f /tmp/midscene-ext.zip \
    # --- Google Chrome for Testing ---
    && if [ -f /tmp/preload/chrome-linux64.zip ]; then cp /tmp/preload/chrome-linux64.zip /tmp/chrome.zip; \
    else \
        CHROME_VERSION=$(curl -fsSL https://googlechromelabs.github.io/chrome-for-testing/last-known-good-versions.json | jq -r '.channels.Stable.version') \
        && echo "Downloading Chrome version: ${CHROME_VERSION}" \
        && curl -fsSL "https://registry.npmmirror.com/-/binary/chrome-for-testing/${CHROME_VERSION}/linux64/chrome-linux64.zip" -o /tmp/chrome.zip; \
    fi \
    && unzip -qo /tmp/chrome.zip -d /opt/ \
    && ln -sf /opt/chrome-linux64/chrome /usr/local/bin/chrome \
    && rm -f /tmp/chrome.zip

# Install midscene-relay (Chrome CDP relay for remote Midscene SDK / Playwright access)
RUN git clone https://github.com/yorkane/midscene-relay.git    /opt/midscene-relay \
    && cd /opt/midscene-relay \
    && pnpm install

# Pre-install EasyConnect and apply pango fix for Ubuntu 24.04
RUN git clone https://github.com/du33169/EasyConnect-linux-fix.git /tmp/EasyConnect-linux-fix \
    && if ls /tmp/preload/*EasyConnect*.deb 1> /dev/null 2>&1; then \
        echo "Found EasyConnect deb in preload. Installing..." \
        && gdebi -n /tmp/preload/*EasyConnect*.deb || true; \
        mkdir -p /etc/skel/Desktop; \
        [ -f /usr/share/applications/EasyConnect.desktop ] && cp /usr/share/applications/EasyConnect.desktop /etc/skel/Desktop/EasyConnect.desktop && chmod +x /etc/skel/Desktop/EasyConnect.desktop || true; \
    fi \
    # Apply pango patch AFTER deb install (deb overwrites the directory)
    && mkdir -p /usr/share/sangfor/EasyConnect \
    && cp /tmp/EasyConnect-linux-fix/patch/*.so* /usr/share/sangfor/EasyConnect/ \
    && rm -rf /tmp/EasyConnect-linux-fix \
    && rm -rf /tmp/preload

# Install Chrome Icon
RUN if [ -f /opt/chrome-linux64/product_logo_256.png ]; then \
        cp /opt/chrome-linux64/product_logo_256.png /usr/share/pixmaps/google-chrome.png; \
    elif [ -f /opt/chrome-linux64/product_logo_48.png ]; then \
        cp /opt/chrome-linux64/product_logo_48.png /usr/share/pixmaps/google-chrome.png; \
    else \
        curl -fsSL https://upload.wikimedia.org/wikipedia/commons/e/e1/Google_Chrome_icon_%28February_2022%29.svg -o /usr/share/pixmaps/google-chrome.svg; \
    fi

# Create standard Chrome desktop shortcut with extension sideload
RUN mkdir -p /etc/skel/Desktop && \
    echo '[Desktop Entry]\n\
Version=1.0\n\
Name=Google Chrome\n\
Exec=/usr/local/bin/chrome --load-extension=/opt/switchyomega,/opt/midscene-ext --no-sandbox --disable-dev-shm-usage --start-maximized --test-type --no-first-run --no-default-browser-check --disable-search-engine-choice-screen --disable-infobars --password-store=basic %U\n\
Icon=google-chrome\n\
Terminal=false\n\
Type=Application\n\
Categories=Network;WebBrowser;' > /etc/skel/Desktop/chrome.desktop && \
    chmod +x /etc/skel/Desktop/chrome.desktop



# Add custom kasmvnc startup script with reduced logging and resolution support
COPY start_kasmvnc.sh /docker_config/start_kasmvnc.sh
RUN chmod +x /docker_config/start_kasmvnc.sh

# Add custom novnc startup script with fixed home dir path and resolution support
COPY start_novnc.sh /docker_config/start_novnc.sh
RUN chmod +x /docker_config/start_novnc.sh

# Inject seamless clipboard bridge into noVNC HTML pages
COPY novnc_clipboard.js /opt/noVNC/novnc_clipboard.js
RUN for f in /opt/noVNC/vnc.html /opt/noVNC/vnc_lite.html /opt/noVNC/index.html; do \
        [ -f "$f" ] && sed -i 's|</body>|<script src="novnc_clipboard.js"></script></body>|' "$f" || true; \
    done \
    # Expose window.UI in vnc.html so the clipboard bridge can access rfb
    && sed -i 's|UI.start|window.UI = UI; UI.start|' /opt/noVNC/vnc.html

# Add custom_env_init hook script (runs after user creation)
COPY custom_env_init.sh /docker_config/custom_env_init.sh
RUN chmod +x /docker_config/custom_env_init.sh

# Add startup script
COPY start.sh /start.sh
RUN chmod +x /start.sh

# Set entrypoint
ENTRYPOINT ["/start.sh"]



# sudo docker build -t midpc -t wasu-wtvdev-registry-test-registry.cn-hangzhou.cr.aliyuncs.com/pub/midpc .

# docker save midpc | xz > midpc.tar.xz -v -T16

# xz -d -k < midpc.tar.xz | sudo docker load
# docker tag midpc wasu-wtvdev-registry-test-registry.cn-hangzhou.cr.aliyuncs.com/pub/midpc
# docker push wasu-wtvdev-registry-test-registry.cn-hangzhou.cr.aliyuncs.com/pub/midpc
