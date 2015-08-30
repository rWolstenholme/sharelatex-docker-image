FROM phusion/baseimage:0.9.17

# Install Node.js and Grunt
RUN curl -sL https://deb.nodesource.com/setup | sudo bash -
RUN apt-get install -y build-essential nodejs
RUN npm install -g grunt-cli

# Set up sharelatex user and home directory
RUN adduser --system --group --home /var/www/sharelatex --no-create-home sharelatex; \
	mkdir -p /var/lib/sharelatex; \
	chown sharelatex:sharelatex /var/lib/sharelatex; \
	mkdir -p /var/log/sharelatex; \
	chown sharelatex:sharelatex /var/log/sharelatex;

# Install ShareLaTeX
RUN apt-get install -y git python
RUN git clone https://github.com/sharelatex/sharelatex.git /var/www/sharelatex

# zlib1g-dev is needed to compile the synctex binaries in the CLSI during `grunt install`.
RUN apt-get install -y zlib1g-dev

RUN cd /var/www/sharelatex; \
	npm install; \
	grunt install;
	
# Minify js assets
RUN cd /var/www/sharelatex/web; \
	grunt compile:minify;

# Install Nginx as a reverse proxy
RUN apt-get install -y nginx;
RUN rm /etc/nginx/sites-enabled/default
ADD nginx/nginx.conf /etc/nginx/nginx.conf
ADD nginx/sharelatex.conf /etc/nginx/sites-enabled/sharelatex.conf

RUN mkdir /etc/service/nginx
ADD runit/nginx.sh /etc/service/nginx/run

# Set up ShareLaTeX services to run automatically on boot
RUN mkdir /etc/service/chat-sharelatex; \
	mkdir /etc/service/clsi-sharelatex; \
	mkdir /etc/service/docstore-sharelatex; \
	mkdir /etc/service/document-updater-sharelatex; \
	mkdir /etc/service/filestore-sharelatex; \
	mkdir /etc/service/real-time-sharelatex; \
	mkdir /etc/service/spelling-sharelatex; \
	mkdir /etc/service/tags-sharelatex; \
	mkdir /etc/service/track-changes-sharelatex; \
	mkdir /etc/service/web-sharelatex; 

ADD runit/chat-sharelatex.sh             /etc/service/chat-sharelatex/run
ADD runit/clsi-sharelatex.sh             /etc/service/clsi-sharelatex/run
ADD runit/docstore-sharelatex.sh         /etc/service/docstore-sharelatex/run
ADD runit/document-updater-sharelatex.sh /etc/service/document-updater-sharelatex/run
ADD runit/filestore-sharelatex.sh        /etc/service/filestore-sharelatex/run
ADD runit/real-time-sharelatex.sh        /etc/service/real-time-sharelatex/run
ADD runit/spelling-sharelatex.sh         /etc/service/spelling-sharelatex/run
ADD runit/tags-sharelatex.sh             /etc/service/tags-sharelatex/run
ADD runit/track-changes-sharelatex.sh    /etc/service/track-changes-sharelatex/run
ADD runit/web-sharelatex.sh              /etc/service/web-sharelatex/run

# Install TexLive
RUN apt-get install -y wget
RUN wget http://mirror.ctan.org/systems/texlive/tlnet/install-tl-unx.tar.gz; \
	mkdir /install-tl-unx; \
	tar -xvf install-tl-unx.tar.gz -C /install-tl-unx --strip-components=1

RUN echo "selected_scheme scheme-full" >> /install-tl-unx/texlive.profile; \
	/install-tl-unx/install-tl -profile /install-tl-unx/texlive.profile
RUN rm -r /install-tl-unx; \
	rm install-tl-unx.tar.gz
	
ENV PATH /usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/local/texlive/2015/bin/x86_64-linux/
	
RUN tlmgr init-usertree
RUN tlmgr update --all

RUN echo "shell_escape = t" >> /usr/local/texlive/2015/texmf.cnf;


RUN tlmgr install latexmk

# Install Aspell
RUN apt-get install -y aspell aspell-en 

# Install unzip for file uploads
RUN apt-get install -y unzip

# phusion/baseimage init script
ADD 00_regen_sharelatex_secrets.sh  /etc/my_init.d/00_regen_sharelatex_secrets.sh
ADD 00_make_sharelatex_data_dirs.sh /etc/my_init.d/00_make_sharelatex_data_dirs.sh
ADD 00_set_docker_host_ipaddress.sh /etc/my_init.d/00_set_docker_host_ipaddress.sh

# Install ShareLaTeX settings file
RUN mkdir /etc/sharelatex
ADD settings.coffee /etc/sharelatex/settings.coffee
ENV SHARELATEX_CONFIG /etc/sharelatex/settings.coffee

EXPOSE 80

ENTRYPOINT ["/sbin/my_init"]
