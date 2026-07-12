FROM alpine:latest

# Step 1: Install OpenSSH and the ultra-tiny 31KB mini_httpd server (with OpenSSL)
RUN apk add --no-cache openssh-server openssh-client mini_httpd openssl

# Step 2: Set root login credentials (usr: root / pass: root)
RUN echo "root:root" | chpasswd

# Step 3: Generate SSH system host keys and create the web root folder
RUN ssh-keygen -A && mkdir -p /var/run/sshd /root/.ssh /var/www/html

# Step 4: Inject your public key and enforce strict 600 permissions
RUN echo "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIH3TAnMJ6yUSPwcfVtSXjglaJ6DBgPdapBR56jphpLs8" > /root/.ssh/authorized_keys && \
    chmod 700 /root/.ssh && \
    chmod 600 /root/.ssh/authorized_keys

# Step 5: Generate a combined Self-Signed HTTPS SSL certificate file for mini_httpd
RUN openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout /etc/ssl/mini_httpd.pem \
    -out /etc/ssl/mini_httpd.pem \
    -subj "/C=US/ST=State/L=City/O=Dev/OU=API/CN=localhost" && \
    chmod 600 /etc/ssl/mini_httpd.pem

# Step 6: Create a simple web page for your uptime ping tool to catch
RUN echo "<html><body><h1>HTTPS Keep-Alive Active</h1></body></html>" > /var/www/html/index.html

# Step 7: Tune SSH server daemon options
RUN sed -i 's/#PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config && \
    sed -i 's/#PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config && \
    echo "Port 8022" >> /etc/ssh/sshd_config

# Expose internal ports (8022 for SSH, 9999 for featherweight HTTPS)
EXPOSE 8022 9999

# Step 8: Fire up the mini HTTPS server, start sshd, and maintain the dual tunnel loop
# -S activates SSL mode, -E specifies the cert path, -p sets the port, -d sets the web root
CMD mini_httpd -S -E /etc/ssl/mini_httpd.pem -p 9999 -d /var/www/html && \
    /usr/sbin/sshd && \
    while true; do \
      ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 -o ServerAliveInterval=30 \
          -N \
          -R root:8022:localhost:8022 \
          -R choco-web:9999:localhost:9999 \
          choco@ssh-j.com; \
      sleep 5; \
    done
