#!/bin/bash

set -u
set -e
set -o pipefail

# set timezone
if [ -n "$TZ" ]; then
  if [ ! -f /etc/timezone ] || [ "$(cat /etc/timezone)" != "$TZ" ]; then
    ln -sf "/usr/share/zoneinfo/${TZ}" "/etc/localtime"
    echo "${TZ}" > /etc/timezone
  fi
fi

if [ -z "${RSA_CERT_FILE}" ] || [ -z "${RSA_PRIVATE_KEY_FILE}" ]; then
  echo "Generating snakeoil certificate"
  make-ssl-cert generate-default-snakeoil
  RSA_CERT_FILE=/etc/ssl/certs/ssl-cert-snakeoil.pem
  RSA_PRIVATE_KEY_FILE=/etc/ssl/private/ssl-cert-snakeoil.key
  # generate snakeoil certificate
fi

# Configure authentication based on AUTH_MODE
if [ "${AUTH_MODE}" == "ldap" ]; then
  echo "Configuring LDAP authentication..."

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

elif [ "${AUTH_MODE}" == "local" ]; then
  echo "Using local user authentication (no LDAP)"
  # Use standard PAM configuration for local users only

elif [ "${AUTH_MODE}" == "virtual" ]; then
  echo "Configuring virtual user authentication..."

  # Create virtual users directory
  # Create virtual user system account for mapping
  if ! id -u "${VIRTUAL_USER_NAME}" > /dev/null 2>&1; then
    useradd -d "${VIRTUAL_USER_HOME}" -s /bin/false "${VIRTUAL_USER_NAME}"
  fi

  mkdir -p $(dirname "${VIRTUAL_USERS_FILE}")
  mkdir -p "${VIRTUAL_USER_HOME}"
  chown "${VIRTUAL_USER_NAME}:${VIRTUAL_USER_NAME}" "${VIRTUAL_USER_HOME}"
  chmod 755 "${VIRTUAL_USER_HOME}"

  # Create empty password file if it doesn't exist
  if [ ! -f "${VIRTUAL_USERS_FILE}" ]; then
    echo "Creating virtual users file at ${VIRTUAL_USERS_FILE}"
    touch "${VIRTUAL_USERS_FILE}"
    chmod 600 "${VIRTUAL_USERS_FILE}"
  fi

  # If no users exist, create default guest account
  if [ ! -s "${VIRTUAL_USERS_FILE}" ]; then
    echo "No virtual users found, creating default guest account..."
    echo "Username: ${VIRTUAL_DEFAULT_USER}"
    echo "Password: ${VIRTUAL_DEFAULT_PASS}"
    htpasswd -bB "${VIRTUAL_USERS_FILE}" "${VIRTUAL_DEFAULT_USER}" "${VIRTUAL_DEFAULT_PASS}"
    echo "WARNING: Default credentials created! Change them in production!"
  fi
  
  # Configure PAM for virtual users
  cat > /etc/pam.d/vsftpd <<EOF
# Virtual user authentication using pam_pwdfile
auth required pam_pwdfile.so pwdfile=${VIRTUAL_USERS_FILE}
account required pam_permit.so
EOF

  echo "Virtual user authentication configured"
  echo "To add users, use: htpasswd -B ${VIRTUAL_USERS_FILE} username"

else
  echo "Warning: Unknown AUTH_MODE '${AUTH_MODE}', defaulting to local authentication"
fi

# vsftpd
cat > /etc/vsftpd.conf <<EOF
# Standalone mode
listen=YES
background=NO

# Access controls
anonymous_enable=${ANONYMOUS_ENABLE}
local_enable=${LOCAL_ENABLE}
write_enable=${WRITE_ENABLE}
anon_upload_enable=${ANON_UPLOAD_ENABLE}
anon_mkdir_write_enable=${ANON_MKDIR_WRITE_ENABLE}

# Security and chroot
chroot_local_user=YES
allow_writeable_chroot=YES
secure_chroot_dir=/var/run/vsftpd/empty

# Virtual user configuration (when AUTH_MODE=virtual)
guest_enable=YES
guest_username=${VIRTUAL_USER_NAME}
virtual_use_local_privs=YES

# Passive mode configuration
pasv_enable=${PASV_ENABLE}
pasv_address=${PASV_ADDRESS}
pasv_min_port=${PASV_MIN_PORT}
pasv_max_port=${PASV_MAX_PORT}

# Active mode configuration
port_enable=${PORT_ENABLE}
connect_from_port_20=${CONNECT_FROM_PORT_20}
ftp_data_port=${FTP_DATA_PORT}

# File permissions
local_umask=${LOCAL_UMASK}
file_open_mode=${FILE_OPEN_MODE}

# Timeouts
idle_session_timeout=${IDLE_SESSION_TIMEOUT}
data_connection_timeout=${DATA_CONNECTION_TIMEOUT}
accept_timeout=${ACCEPT_TIMEOUT}
connect_timeout=${CONNECT_TIMEOUT}

# Rate limiting
max_per_ip=${RATE_MAX_PER_IP}
max_clients=${MAX_CLIENTS}
max_login_fails=${MAX_LOGIN_FAILS}
delay_failed_login=${DELAY_FAILED_LOGIN}

# Logging
xferlog_enable=${XFERLOG_ENABLE}
xferlog_std_format=${XFERLOG_STD_FORMAT}
log_ftp_protocol=${LOG_FTP_PROTOCOL}
syslog_enable=${SYSLOG_ENABLE}
vsftpd_log_file=${VSFTPD_LOG_FILE}

# Messages and banners
dirmessage_enable=${DIRMESSAGE_ENABLE}
ftpd_banner=${FTPD_BANNER}

# Locale
use_localtime=${USE_LOCALTIME}
utf8_filesystem=YES

# SSL/TLS configuration
ssl_enable=${SSL_ENABLE}
ssl_tlsv1=${SSL_TLSV1}
ssl_sslv2=${SSL_SSLV2}
ssl_sslv3=${SSL_SSLV3}
ssl_ciphers=${SSL_CIPHERS}
rsa_cert_file=${RSA_CERT_FILE}
rsa_private_key_file=${RSA_PRIVATE_KEY_FILE}
force_local_data_ssl=${FORCE_LOCAL_DATA_SSL}
force_local_logins_ssl=${FORCE_LOCAL_LOGINS_SSL}
require_ssl_reuse=${REQUIRE_SSL_REUSE}

# PAM integration
pam_service_name=vsftpd
session_support=${SESSION_SUPPORT}

# Additional security
hide_ids=${HIDE_IDS}
ls_recurse_enable=${LS_RECURSE_ENABLE}
download_enable=${DOWNLOAD_ENABLE}
dirlist_enable=${DIRLIST_ENABLE}
chmod_enable=${CHMOD_ENABLE}
delete_failed_uploads=${DELETE_FAILED_UPLOADS}
ascii_upload_enable=${ASCII_UPLOAD_ENABLE}
ascii_download_enable=${ASCII_DOWNLOAD_ENABLE}

# Email restrictions for anonymous (if enabled)
deny_email_enable=YES
banned_email_file=/etc/vsftpd.banned_emails

# Process management
setproctitle_enable=${SETPROCTITLE_ENABLE}
text_userdb_names=${TEXT_USERDB_NAMES}
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
