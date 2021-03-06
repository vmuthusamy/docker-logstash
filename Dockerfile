FROM       ubuntu:14.04

MAINTAINER Edward De Faria <edward.de-faria@ovh.net>

ENV        DEBIAN_FRONTEND noninteractive

# Install Java 8
RUN        apt-get update -qq && \
           apt-get install -qq curl software-properties-common > /dev/null && \
           apt-get update -qq && \
           add-apt-repository -y ppa:webupd8team/java && \
           apt-get update -qq && \
           echo debconf shared/accepted-oracle-license-v1-1 select true | debconf-set-selections && \
           echo debconf shared/accepted-oracle-license-v1-1 seen true | debconf-set-selections && \
           apt-get install -qq oracle-java8-installer oracle-java8-set-default > /dev/null && \
           apt-get clean && rm -rf /var/lib/apt/lists/* && \
           rm -rf /var/cache/oracle-jdk8-installer
ENV 	   JAVA_HOME /usr/lib/jvm/java-8-oracle

# Install logstash dependencies
RUN        apt-get update -qq && \
           apt-get install -qq --no-install-recommends ruby ruby-dev jruby make rake git ca-certificates ca-certificates-java  $(apt-get -s dist-upgrade|awk '/^Inst.*ecurity/ {print $2}') > /dev/null && \
           apt-get clean && rm -rf /var/lib/apt/lists/*

# Install logstash from package
RUN        wget -q -O - http://packages.elasticsearch.org/GPG-KEY-elasticsearch | apt-key add - && \
           echo 'deb http://packages.elasticsearch.org/logstash/2.4/debian stable main' > /etc/apt/sources.list.d/logstash.list && \
           apt-get update -qq && \
           apt-get install -qq logstash && \
           apt-get clean && rm -rf /var/lib/apt/lists/* && \
           cd /opt/logstash ; git init && \
           mkdir -p /etc/logstash/conf.d
# Install Logstash from source
#ENV        LOGSTASH_VERSION 2.4.0
#RUN        cd /tmp && wget -q https://github.com/elastic/logstash/archive/v${LOGSTASH_VERSION}.tar.gz && \
#           tar -xzf v${LOGSTASH_VERSION}.tar.gz -C /opt && \
#           mv /opt/logstash-${LOGSTASH_VERSION} /opt/logstash && \
#           rm -f v${LOGSTASH_VERSION}.tar.gz && \
#           cd /opt/logstash  && \
#           rake bootstrap >/dev/null && \
#           mkdir -p /etc/logstash/conf.d

# Copy and install patched version for better supporting gelf
RUN        cd /opt && git clone https://github.com/edefaria/patch-gelf-output-logstash && \
           /opt/patch-gelf-output-logstash/uninstall-plugin.sh && \
           /opt/patch-gelf-output-logstash/update-gelf.sh && \
           /opt/logstash/bin/plugin install logstash-filter-aggregate && \
           /opt/logstash/bin/plugin install logstash-filter-prune

# Update logstash-filter-geoip to 3.0.1 to support ipv6 => TO DELETE in logstash 5.0.0
# Update logstash-output-tcp to 3.2.0 to support TLS => TO DELETE in logstash 5.0.0
RUN  /opt/logstash/bin/logstash-plugin install --version 3.0.1 logstash-filter-geoip && \
     /opt/logstash/bin/logstash-plugin install --version 3.2.0 logstash-output-tcp


VOLUME     [ "/etc/logstash/conf.d",  "/opt/logstash/patterns" ]

COPY       patterns /opt/logstash/patterns
#COPY       conf.d        /opt/conf.d
COPY       logstash.conf /opt/logstash.conf
COPY       logstash.crt  /opt/logstash-forwarder/logstash.crt
COPY       logstash.key  /opt/logstash-forwarder/logstash.key

ADD        start.sh /usr/local/bin/start.sh
CMD        [ "/usr/local/bin/start.sh" ]
