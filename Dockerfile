FROM cachyos/cachyos:latest

# =========================================================================
# STEP 1: FORCE THE HOSTNAME OVERRIDE
# This changes your prompt to "apex-core"
# =========================================================================
ENV HOSTNAME=apex-core

# Step 2: Install OpenSSH, Python 3, and build tools (base-devel, cmake) for zero-error bot compilation
RUN pacman -Syu --noconfirm openssh python python-pip base-devel cmake ninja git && \
    pacman -Scc --noconfirm

# Step 3: Set root login credentials (usr: root / pass: root)
RUN echo "root:root" | chpasswd

# Step 4: Generate system host keys and create system folders
RUN ssh-keygen -A && mkdir -p /var/run/sshd /root/.ssh /var/www/html

# Step 5: Inject your public key and lock down directory permissions
RUN echo "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIH3TAnMJ6yUSPwcfVtSXjglaJ6DBgPdapBR56jphpLs8" > /root/.ssh/authorized_keys && \
    chmod 700 /root/.ssh && \
    chmod 600 /root/.ssh/authorized_keys

# Step 6: Tune SSH server configuration rules
RUN sed -i 's/#PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config && \
    sed -i 's/#PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config && \
    echo "Port 8022" >> /etc/ssh/sshd_config

# Step 7: Create a basic landing page for Render's active uptime checks
RUN echo "<html><body><h1>Render Health Check Bypass Active (CachyOS)</h1></body></html>" > /var/www/html/index.html

# Expose 10000 for Render to listen to, and 8022 for internal use
EXPOSE 8022 10000

# Step 8: Boot Python web server in background, spin up sshd, and hold the reverse tunnel open
CMD python3 -m http.server 10000 --directory /var/www/html > /dev/null 2>&1 & \
    /usr/bin/sshd && \
    while true; do \
      ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 -o ServerAliveInterval=30 \
          -N \
          -R cachy-render:22:localhost:8022 \
          choco@ssh-j.com; \
      sleep 5; \
    done
