# Website Evidence Collector running in a tiny Alpine Docker container
#
# Usage:
#
# build from source code folder: docker build -t website-evidence-collector .
# run container with e.g.:
# docker run --rm -it --cap-add=SYS_ADMIN -v $(pwd)/output:/output \
#   website-evidence-collector http://example.com/about
# If you hit the Error: EACCES: permission denied,
# then try "mkdir output && chown 1000 output"



# RUN: docker run -p 80:8080 --cap-add=SYS_ADMIN -v $(pwd)/output:/output --name wec-web wec 
FROM alpine:3.15.0

LABEL maintainer="Robert Riemann <robert.riemann@edps.europa.eu>"

LABEL org.label-schema.description="Website Evidence Collector running in a tiny Alpine Docker container" \
      org.label-schema.name="website-evidence-collector" \
      org.label-schema.usage="https://github.com/EU-EDPS/website-evidence-collector/blob/master/README.md" \
      org.label-schema.vcs-url="https://github.com/EU-EDPS/website-evidence-collector" \
      org.label-schema.vendor="European Data Protection Supervisor (EDPS)" \
      org.label-schema.license="EUPL-1.2"

# Installs latest Chromium (77) package.
RUN apk add --no-cache \
      chromium \
      nss \
      freetype \
      freetype-dev \
      harfbuzz \
      ca-certificates \
      ttf-freefont \
      nodejs \
      yarn~=1.22 \
	openjdk8 \

# Packages linked to testssl.sh
      bash procps drill coreutils libidn curl \
# Toolbox for advanced interactive use of WEC in container
      parallel jq grep aha

RUN mkdir /opt/tomcat

# Add user so we don't need --no-sandbox and match first linux uid 1000
RUN addgroup --system --gid 1001 collector \
      && adduser --system --uid 1000 --ingroup collector --shell /bin/bash collector \
      && mkdir -p /output \
      && chown -R collector:collector /output \
	  && chown -R collector:collector /opt/tomcat

COPY . /opt/website-evidence-collector/

# Install Testssl.sh
RUN curl -SL https://github.com/drwetter/testssl.sh/archive/refs/tags/v3.0.6.tar.gz | \
      tar -xz --directory /opt

# Run everything after as non-privileged user.

WORKDIR /home/collector


# Tell Puppeteer to skip installing Chrome. We'll be using the installed package.
ENV PUPPETEER_SKIP_CHROMIUM_DOWNLOAD true

RUN yarn global add file:/opt/website-evidence-collector --prefix /home/collector
USER collector

# Let Puppeteer use system Chromium
ENV PUPPETEER_EXECUTABLE_PATH /usr/bin/chromium-browser

ENV PATH="/home/collector/bin:/opt/testssl.sh-3.0.6:${PATH}"
# Let website evidence collector run chrome without sandbox
# ENV WEC_BROWSER_OPTIONS="--no-sandbox"
# Configure default command in Docker container
#ENTRYPOINT ["/home/collector/bin/website-evidence-collector"]
COPY ./web/apache-tomcat-9.0.59.tar.gz /tmp/

RUN tar xvzf /tmp/apache-tomcat-9.0.59.tar.gz  --strip-components 1 --directory /opt/tomcat && \
chmod +x -R /opt/tomcat/bin

RUN rm -rf /opt/tomcat/webapps/ROOT \
rm -rf /opt/tomcat/webapps/manager \
rm -rf /opt/tomcat/webapps/docs \
rm -rf /opt/tomcat/webapps/examples \
rm -rf /opt/tomcat/webapps/host-manager

COPY ./web/ROOT.war /opt/tomcat/webapps

WORKDIR /
VOLUME /output



# Used Pupetteer to save PDF
# https://blog.risingstack.com/pdf-from-html-node-js-puppeteer/
EXPOSE 8080
CMD ["/opt/tomcat/bin/catalina.sh", "run"]