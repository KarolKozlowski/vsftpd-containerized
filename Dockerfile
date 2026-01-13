FROM debian:12.13

LABEL org.label-schema.build-date=FIXME \
      org.label-schema.license=MIT \
      org.label-schema.name=vsftpd \
      org.label-schema.vcs-ref=FIXME \
      org.label-schema.vcs-url=https://github.com/karolkozlowski/vsftpd-containerized

COPY src/debconf-selections /var/lib/debconf-selections
RUN debconf-set-selections /var/lib/debconf-selections

RUN apt-get -y update &&  \ 
    apt-get install --no-install-recommends -y vsftpd libpam-ldapd libnss-ldap ssl-cert && \
    rm -rf /var/lib/apt/lists/*

ENV LDAP_URI=ldaps://ldap.example.com \
    LDAP_BASE=dc=example,dc=com \
    LDAP_BINDDN=cn=user,ou=technical,dc=example,dc=com \
    LDAP_BINDPW=CHANGEME \
    NSLCD_DEBUG=no \
    FTP_GROUP='ftpuser' \
    ANONYMOUS_ENABLE=NO \
    WRITE_ENABLE=YES \
    LOCAL_ENABLE=YES \
    LOCAL_UMASK=022 \
    ANON_UPLOAD_ENABLE=NO \
    ANON_MKDIR_WRITE_ENABLE=NO \
    DIRMESSAGE_ENABLE=yes \
    USE_LOCALTIME=YES \
    XFERLOG_ENABLE=YES \
    IDLE_SESSION_TIMEOUT=600 \
    RATE_MAX_PER_IP=5 \
    SSL_ENABLE=YES \
    SSL_CIPHERS=HIGH \
    RSA_CERT_FILE= \
    RSA_PRIVATE_KEY_FILE= \
    FTPD_BANNER="Welcome to FTP service." \
    PASV_ENABLE=YES \
    PASV_ADDRESS= \
    PASV_MIN_PORT=40000 \
    PASV_MAX_PORT=40100 \
    TZ=UTC
    
EXPOSE 21 $PASV_MIN_PORT-$PASV_MAX_PORT
COPY --chown=root --chmod=750 src/entrypoint.sh /usr/local/bin/
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]