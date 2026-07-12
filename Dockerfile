FROM alpine:latest

# =========================================================================
# STEP 1: FORCE THE HOSTNAME OVERRIDE
# This changes your prompt from "srv-d99v7qks728c73duq9r0..." to "apex-core"
# =========================================================================
ENV HOSTNAME=apex-core

# Step 2: Install OpenSSH tools and busybox-extras for the native tiny HTTP server
RUN apk add --no-cache openssh-server openssh-client busybox-extras

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
    echo "Port 22" >> /etc/ssh/sshd_config

# Step 7: Create a basic landing page for Render's active uptime checks
RUN echo "<html><body><h1>Render Health Check Bypass Active</h1></body></html>" > /var/www/html/index.html


# Expose 9999 for Render to listen to, and 8022 for internal use
EXPOSE 8022 10000

# Step 7: Boot HTTP server locally, spin up sshd, and hold the solo SSH reverse tunnel open
# Notice: Only one -R flag is used here now since Render handles the web layer entirely locally.
CMD httpd -p 10000 -h /var/www/html && \
    /usr/sbin/sshd && \
    while true; do \
      ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 -o ServerAliveInterval=30 \
          -N \
          -R alpine-render:22:localhost:22 \
          choco@ssh-j.com; \
      sleep 5; \
    done
