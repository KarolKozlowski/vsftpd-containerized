FROM debian:13.3

ARG BUILD_DATE
ARG VCS_REF

LABEL org.label-schema.build-date="${BUILD_DATE}" \
      org.label-schema.license="MIT" \
      org.label-schema.name="vsftpd" \
      org.label-schema.vcs-ref="${VCS_REF}" \
      org.label-schema.vcs-url="https://github.com/karolkozlowski/vsftpd-containerized" \
      org.opencontainers.image.created="${BUILD_DATE}" \
      org.opencontainers.image.source="https://github.com/karolkozlowski/vsftpd-containerized" \
      org.opencontainers.image.revision="${VCS_REF}" \
      org.opencontainers.image.title="vsftpd" \
      org.opencontainers.image.description="vsftpd FTP server with LDAP authentication" \
      org.opencontainers.image.licenses="MIT"

COPY src/debconf-selections /var/lib/debconf-selections
RUN debconf-set-selections /var/lib/debconf-selections

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get -y update &&  \
    apt-get install --no-install-recommends -y vsftpd libpam-ldapd libnss-ldap libpam-pwdfile apache2-utils ssl-cert && \
    rm -rf /var/lib/apt/lists/* && \
    rm -f /etc/ssl/private/ssl-cert-snakeoil.key /etc/ssl/certs/ssl-cert-snakeoil.pem

ENV LDAP_URI=ldaps://ldap.example.com \
    LDAP_BASE=dc=example,dc=com \
    LDAP_BINDDN=cn=user,ou=technical,dc=example,dc=com \
    LDAP_BINDPW=CHANGEME \
    NSLCD_DEBUG=no \
    AUTH_MODE=ldap \
    VIRTUAL_USERS_FILE=/etc/vsftpd/virtual_users.passwd \
    VIRTUAL_USER_HOME=/home/vftp \
    VIRTUAL_DEFAULT_USER=guest \
    VIRTUAL_DEFAULT_PASS=guest123 \
    FTP_GROUP='ftpuser' \
    ANONYMOUS_ENABLE=NO \
    WRITE_ENABLE=YES \
    LOCAL_ENABLE=YES \
    LOCAL_UMASK=022 \
    ANON_UPLOAD_ENABLE=NO \
    ANON_MKDIR_WRITE_ENABLE=NO \
    DIRMESSAGE_ENABLE=YES \
    USE_LOCALTIME=YES \
    XFERLOG_ENABLE=YES \
    XFERLOG_STD_FORMAT=NO \
    LOG_FTP_PROTOCOL=NO \
    SYSLOG_ENABLE=NO \
    VSFTPD_LOG_FILE=/var/log/vsftpd.log \
    IDLE_SESSION_TIMEOUT=600 \
    DATA_CONNECTION_TIMEOUT=300 \
    ACCEPT_TIMEOUT=60 \
    CONNECT_TIMEOUT=60 \
    RATE_MAX_PER_IP=5 \
    MAX_CLIENTS=0 \
    MAX_LOGIN_FAILS=3 \
    DELAY_FAILED_LOGIN=1 \
    PORT_ENABLE=YES \
    CONNECT_FROM_PORT_20=NO \
    FTP_DATA_PORT=20 \
    FILE_OPEN_MODE=0666 \
    SSL_ENABLE=YES \
    SSL_TLSV1=YES \
    SSL_SSLV2=NO \
    SSL_SSLV3=NO \
    SSL_CIPHERS=HIGH \
    FORCE_LOCAL_DATA_SSL=YES \
    FORCE_LOCAL_LOGINS_SSL=YES \
    REQUIRE_SSL_REUSE=NO \
    RSA_CERT_FILE= \
    RSA_PRIVATE_KEY_FILE= \
    SESSION_SUPPORT=YES \
    HIDE_IDS=NO \
    LS_RECURSE_ENABLE=NO \
    DOWNLOAD_ENABLE=YES \
    DIRLIST_ENABLE=YES \
    CHMOD_ENABLE=YES \
    DELETE_FAILED_UPLOADS=NO \
    ASCII_UPLOAD_ENABLE=NO \
    ASCII_DOWNLOAD_ENABLE=NO \
    SETPROCTITLE_ENABLE=NO \
    TEXT_USERDB_NAMES=NO \
    FTPD_BANNER="Welcome to FTP service." \
    PASV_ENABLE=YES \
    PASV_ADDRESS= \
    PASV_MIN_PORT=40000 \
    PASV_MAX_PORT=40100 \
    TZ=UTC

EXPOSE 21 $PASV_MIN_PORT-$PASV_MAX_PORT
COPY --chown=root --chmod=750 src/entrypoint.sh /usr/local/bin/
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]