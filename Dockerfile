FROM ubuntu:22.04

RUN apt-get -y update && apt-get -y upgrade -y && apt-get install -y sudo
RUN sudo apt-get install -y curl ffmpeg git locales nano python3-pip screen ssh unzip wget  

# Set UTF-8 locale
RUN localedef -i en_US -c -f UTF-8 -A /usr/share/locale/locale.alias en_US.UTF-8
ENV LANG en_US.utf8

# Install Node.js
RUN curl -sL https://deb.nodesource.com/setup_21.x | bash -
RUN sudo apt-get install -y nodejs

# Install Python packages
RUN pip3 install aiohttp

# Setup NGROK
ARG NGROK_TOKEN
ENV NGROK_TOKEN=${NGROK_TOKEN}
RUN wget -O ngrok.zip https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-linux-amd64.zip
RUN unzip ngrok.zip

# SSH Setup
RUN mkdir /run/sshd
RUN echo 'PermitRootLogin yes' >>  /etc/ssh/sshd_config 
RUN echo "PasswordAuthentication yes" >> /etc/ssh/sshd_config
RUN echo root:kaal | chpasswd

# Create web hook server
RUN echo 'import asyncio' > /webhook.py && \
    echo 'from aiohttp import web' >> /webhook.py && \
    echo 'async def handle(request): return web.Response(text="OK")' >> /webhook.py && \
    echo 'async def main():' >> /webhook.py && \
    echo '    app = web.Application()' >> /webhook.py && \
    echo '    app.router.add_get("/", handle)' >> /webhook.py && \
    echo '    runner = web.AppRunner(app)' >> /webhook.py && \
    echo '    await runner.setup()' >> /webhook.py && \
    echo '    site = web.TCPSite(runner, "0.0.0.0", 8080)' >> /webhook.py && \
    echo '    await site.start()' >> /webhook.py && \
    echo '    while True: await asyncio.sleep(3600)' >> /webhook.py && \
    echo 'asyncio.run(main())' >> /webhook.py

# Create startup script
RUN echo '#!/bin/bash' > /start && \
    echo "./ngrok config add-authtoken \$NGROK_TOKEN" >> /start && \
    echo "./ngrok tcp --region ap 22 &>/dev/null &" >> /start && \
    echo "/usr/sbin/sshd" >> /start && \
    echo "python3 /webhook.py" >> /start
RUN chmod +x /start

EXPOSE 22 80 8888 8080 443 5130 5131 5132 5133 5134 5135 3306

CMD ["/start"]
