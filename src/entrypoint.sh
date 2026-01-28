#!/bin/bash

set -u
set -e
set -o pipefail

# set timezone
if [ ! -f /etc/timezone ] && [ -n "$TZ" ]; then
  cp "/usr/share/zoneinfo/${TZ}" "/etc/localtime"
  echo "${TZ}" > /etc/timezone
fi

if [ -z "${RSA_CERT_FILE}" ] || [ -z "${RSA_PRIVATE_KEY_FILE}" ]; then
  echo "Generating snakeoil certificate"
  make-ssl-cert generate-default-snakeoil
  RSA_CERT_FILE=/etc/ssl/certs/ssl-cert-snakeoil.pem
  RSA_PRIVATE_KEY_FILE=/etc/ssl/private/ssl-cert-snakeoil.key
  # generate snakeoil certificate
fi

# configure ftp access group
if [ -n "${FTP_GROUP}" ]; then
  echo "Configuring access group: '${FTP_GROUP}'"
  echo "${FTP_GROUP}" > /etc/ftpgroup
  echo "# Allow login only from users in a specific group" >> /etc/pam.d/vsftpd
  echo "auth    required        pam_listfile.so onerr=fail item=group sense=allow file=/etc/ftpgroup" >> /etc/pam.d/vsftpd
fi

# nslcd
cat > /etc/nslcd.conf <<EOF
# /etc/nslcd.conf
# nslcd configuration file. See nslcd.conf(5)
# for details.

# The user and group nslcd should run as.
uid nslcd
gid nslcd

# The location at which the LDAP server(s) should be reachable.
uri ${LDAP_URI}

# The search base that will be used for all queries.
base ${LDAP_BASE}

# The LDAP protocol version to use.
#ldap_version 3

# The DN to bind with for normal lookups.
binddn ${LDAP_BINDDN}
bindpw ${LDAP_BINDPW}

# SSL options
ssl on
tls_reqcert demand
tls_cacertfile /etc/ssl/certs/ca-certificates.crt

# The search scope.
#scope sub
EOF

if [ "${NSLCD_DEBUG}" == "yes" ]; then
  nslcd -d &
else
  nslcd &
fi

# vsftpd
cat > /etc/vsftpd.conf <<EOF
listen=YES

# Configure passive mode
pasv_enable=${PASV_ENABLE}
pasv_address=${PASV_ADDRESS}
pasv_min_port=${PASV_MIN_PORT}
pasv_max_port=${PASV_MAX_PORT}


# Allow anonymous FTP? (Disabled by default).
anonymous_enable=${ANONYMOUS_ENABLE}

# Uncomment this to allow local users to log in.
local_enable=${LOCAL_ENABLE}

# Uncomment this to enable any form of FTP write command.
write_enable=${WRITE_ENABLE}

allow_writeable_chroot=YES

# Default umask for local users is 077. You may wish to change this to 022,
# if your users expect that (022 is used by most other ftpd's)
local_umask=${LOCAL_UMASK}

# Uncomment this to allow the anonymous FTP user to upload files. This only
# has an effect if the above global write enable is activated. Also, you will
# obviously need to create a directory writable by the FTP user.
anon_upload_enable=${ANON_UPLOAD_ENABLE}

# Uncomment this if you want the anonymous FTP user to be able to create
# new directories.
anon_mkdir_write_enable=${ANON_MKDIR_WRITE_ENABLE}

# Activate directory messages - messages given to remote users when they
# go into a certain directory.
dirmessage_enable=${DIRMESSAGE_ENABLE}

# If enabled, vsftpd will display directory listings with the time
# in  your  local  time  zone.  The default is to display GMT. The
# times returned by the MDTM FTP command are also affected by this
# option.
use_localtime=${USE_LOCALTIME}

# Activate logging of uploads/downloads.
xferlog_enable=${XFERLOG_ENABLE}

# Make sure PORT transfer connections originate from port 20 (ftp-data).
connect_from_port_20=YES

# If you want, you can arrange for uploaded anonymous files to be owned by
# a different user. Note! Using "root" for uploaded files is not
# recommended!
#chown_uploads=YES
#chown_username=whoever

# You may change the default value for timing out an idle session.
idle_session_timeout=${IDLE_SESSION_TIMEOUT}

# You may change the default value for timing out a data connection.
#data_connection_timeout=120

# It is recommended that you define on your system a unique user which the
# ftp server can use as a totally isolated and unprivileged user.
#nopriv_user=ftpsecure

# Enable this and the server will recognise asynchronous ABOR requests. Not
# recommended for security (the code is non-trivial). Not enabling it,
# however, may confuse older FTP clients.
#async_abor_enable=YES

# By default the server will pretend to allow ASCII mode but in fact ignore
# the request. Turn on the below options to have the server actually do ASCII
# mangling on files when in ASCII mode.
# Beware that on some FTP servers, ASCII support allows a denial of service
# attack (DoS) via the command "SIZE /big/file" in ASCII mode. vsftpd
# predicted this attack and has always been safe, reporting the size of the
# raw file.
# ASCII mangling is a horrible feature of the protocol.
#ascii_upload_enable=YES
#ascii_download_enable=YES

# You may fully customise the login banner string:
ftpd_banner=${FTPD_BANNER}

# You may specify a file of disallowed anonymous e-mail addresses. Apparently
# useful for combatting certain DoS attacks.
deny_email_enable=YES
# (default follows)
banned_email_file=/etc/vsftpd.banned_emails

# You may restrict local users to their home directories.  See the FAQ for
# the possible risks in this before using chroot_local_user or
# chroot_list_enable below.
chroot_local_user=YES

# You may activate the "-R" option to the builtin ls. This is disabled by
# default to avoid remote users being able to cause excessive I/O on large
# sites. However, some broken FTP clients such as "ncftp" and "mirror" assume
# the presence of the "-R" option, so there is a strong case for enabling it.
#ls_recurse_enable=YES

# Customization
#
# Some of vsftpd's settings don't fit the filesystem layout by
# default.

# This option should be the name of a directory which is empty.  Also, the
# directory should not be writable by the ftp user. This directory is used
# as a secure chroot() jail at times vsftpd does not require filesystem
# access.
secure_chroot_dir=/var/run/vsftpd/empty

# This string is the name of the PAM service vsftpd will use.
pam_service_name=vsftpd

# This option specifies the location of the RSA certificate to use for SSL
# encrypted connections.
ssl_enable=${SSL_ENABLE}
ssl_ciphers=${SSL_CIPHERS}
rsa_cert_file=${RSA_CERT_FILE}
rsa_private_key_file=${RSA_PRIVATE_KEY_FILE}

# rate limiting
max_per_ip=${RATE_MAX_PER_IP}

# Uncomment this to indicate that vsftpd use a utf8 filesystem.
utf8_filesystem=YES
EOF

# ensure banned email list is present
BANNED_EMAIL_FILE=$(grep banned_email_file /etc/vsftpd.conf | cut -d = -f 2)
[ ! -e "${BANNED_EMAIL_FILE}" ] && touch "${BANNED_EMAIL_FILE}"

# ensure secure chroot dir is present
SECURE_CHROOT_DIR=$(grep secure_chroot_dir /etc/vsftpd.conf | cut -d = -f 2)
[ ! -d "${SECURE_CHROOT_DIR}" ] && mkdir -p "${SECURE_CHROOT_DIR}"

# ensure proper permissions on the log file
LOGFILE=/var/log/vsftpd.log
touch "${LOGFILE}"
chmod 640 "${LOGFILE}"
chown root:adm "${LOGFILE}"

tail -f /var/log/vsftpd.log &

/usr/sbin/vsftpd /etc/vsftpd.conf
