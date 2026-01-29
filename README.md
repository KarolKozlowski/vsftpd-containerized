# vsftpd-containerized

A containerized vsftpd FTP server with LDAP authentication support.

## Features

- 🔐 Multiple authentication modes (LDAP, local users, virtual users)
- 🔒 SSL/TLS encryption support
- 🌍 Multi-platform support (amd64, arm64)
- ⚙️ Extensive configuration via environment variables
- 🛡️ Fail2ban with TCP Wrappers support
- 🐳 Docker and Docker Compose ready

## Authentication Modes

### LDAP Authentication (default)

```bash
docker run -d \
  --name vsftpd \
  -p 21:21 \
  -p 40000-40100:40000-40100 \
  -e AUTH_MODE=ldap \
  -e LDAP_URI=ldaps://ldap.example.com \
  -e LDAP_BASE=dc=example,dc=com \
  -e LDAP_BINDDN=cn=user,ou=technical,dc=example,dc=com \
  -e LDAP_BINDPW=yourpassword \
  ghcr.io/karolkozlowski/vsftpd-containerized:latest
```

### Virtual Users (file-based authentication)

```bash
docker run -d \
  --name vsftpd \
  -p 21:21 \
  -p 40000-40100:40000-40100 \
  -e AUTH_MODE=virtual \
  -e PASV_ADDRESS=your.server.ip.address \
  ghcr.io/karolkozlowski/vsftpd-containerized:latest
```

Default credentials: `guest` / `guest123` (change in production!)

Add additional users:

```bash
docker exec vsftpd htpasswd -bB /etc/vsftpd/virtual_users.passwd username password
```

Or mount an external password file:

```bash
# Create password file on host
htpasswd -cbB virtual_users.passwd myuser mypassword
htpasswd -bB virtual_users.passwd anotheruser anotherpass

# Run container with mounted password file
docker run -d \
  --name vsftpd \
  -p 21:21 \
  -p 40000-40100:40000-40100 \
  -v $(pwd)/virtual_users.passwd:/etc/vsftpd/virtual_users.passwd:ro \
  -e AUTH_MODE=virtual \
  -e PASV_ADDRESS=your.server.ip.address \
  ghcr.io/karolkozlowski/vsftpd-containerized:latest
```

### Local System Users

```bash
docker run -d \
  --name vsftpd \
  -p 21:21 \
  -p 40000-40100:40000-40100 \
  -e AUTH_MODE=local \
  ghcr.io/karolkozlowski/vsftpd-containerized:latest
```

### Using Docker Compose

```yaml
services:
  vsftpd:
    image: ghcr.io/karolkozlowski/vsftpd-containerized:latest
    ports:
      - "21:21"
      - "40000-40100:40000-40100"
    environment:
      FTPD_BANNER: "Welcome to FTP service"
      LDAP_URI: ldaps://ldap.example.com
      LDAP_BASE: dc=example,dc=com
      LDAP_BINDDN: cn=user,ou=technical,dc=example,dc=com
      LDAP_BINDPW: yourpassword
      PASV_ADDRESS: your.server.ip.address
      TZ: UTC
    volumes:
      - ./ftp-data:/home
```

## Environment Variables

### Authentication Mode

| Variable        | Description                           | Default  |
| --------------- | ------------------------------------- | -------- |
| `AUTH_MODE`     | Authentication mode: `ldap`, `local`, or `virtual` | `ldap` |

### LDAP Configuration (AUTH_MODE=ldap)

| Variable        | Description                    | Default                                    |
| --------------- | ------------------------------ | ------------------------------------------ |
| `LDAP_URI`      | LDAP server URI                | `ldaps://ldap.example.com`                 |
| `LDAP_BASE`     | LDAP search base               | `dc=example,dc=com`                        |
| `LDAP_BINDDN`   | LDAP bind DN                   | `cn=user,ou=technical,dc=example,dc=com`   |
| `LDAP_BINDPW`   | LDAP bind password             | `CHANGEME`                                 |
| `NSLCD_DEBUG`   | Enable nslcd debug mode        | `no`                                       |
| `FTP_GROUP`     | Restrict FTP access to group   | `ftpuser`                                  |

### Virtual User Configuration (AUTH_MODE=virtual)

| Variable               | Description                         | Default                          |
| ---------------------- | ----------------------------------- | -------------------------------- |
| `VIRTUAL_USERS_FILE`   | Path to htpasswd password file      | `/etc/vsftpd/virtual_users.passwd` |
| `VIRTUAL_USER_HOME`    | Home directory for virtual users    | `/home/vftp`                     |
| `VIRTUAL_USER_NAME`    | System user to map virtual users to | `vftp`                           |
| `VIRTUAL_DEFAULT_USER` | Default username created on first run | `guest`                        |
| `VIRTUAL_DEFAULT_PASS` | Default password for default user   | `guest123`                       |

### FTP Server Configuration

| Variable                  | Description                       | Default                    |
| ------------------------- | --------------------------------- | -------------------------- |
| `ANONYMOUS_ENABLE`        | Allow anonymous FTP               | `NO`                       |
| `LOCAL_ENABLE`            | Allow local users to log in       | `YES`                      |
| `WRITE_ENABLE`            | Enable FTP write commands         | `YES`                      |
| `LOCAL_UMASK`             | Default umask for local users     | `022`                      |
| `ANON_UPLOAD_ENABLE`      | Allow anonymous uploads           | `NO`                       |
| `ANON_MKDIR_WRITE_ENABLE` | Allow anonymous directory creation| `NO`                       |
| `DIRMESSAGE_ENABLE`       | Show directory messages           | `yes`                      |
| `USE_LOCALTIME`           | Use local timezone for listings   | `YES`                      |
| `XFERLOG_ENABLE`          | Enable transfer logging           | `YES`                      |
| `IDLE_SESSION_TIMEOUT`    | Idle session timeout (seconds)    | `600`                      |
| `RATE_MAX_PER_IP`         | Max connections per IP            | `5`                        |
| `FTPD_BANNER`             | FTP banner message                | `Welcome to FTP service.`  |

### SSL/TLS Configuration

| Variable                | Description                 | Default                     |
| ----------------------- | --------------------------- | --------------------------- |
| `SSL_ENABLE`            | Enable SSL/TLS              | `YES`                       |
| `SSL_CIPHERS`           | SSL cipher suite            | `HIGH`                      |
| `RSA_CERT_FILE`         | Path to RSA certificate     | (auto-generated snakeoil)   |
| `RSA_PRIVATE_KEY_FILE`  | Path to RSA private key     | (auto-generated snakeoil)   |

### Passive Mode Configuration

| Variable         | Description                   | Default  |
| ---------------- | ----------------------------- | -------- |
| `PASV_ENABLE`    | Enable passive mode           | `YES`    |
| `PASV_ADDRESS`   | Public IP for passive mode    | (empty)  |
| `PASV_MIN_PORT`  | Passive mode minimum port     | `40000`  |
| `PASV_MAX_PORT`  | Passive mode maximum port     | `40100`  |

### Fail2ban and TCP Wrappers

| Variable             | Description                              | Default      |
| -------------------- | ---------------------------------------- | ------------ |
| `FAIL2BAN_ENABLE`    | Enable fail2ban integration              | `YES`        |
| `FAIL2BAN_BANTIME`   | Ban time (seconds)                       | `600`        |
| `FAIL2BAN_FINDTIME`  | Find time window (seconds)               | `600`        |
| `FAIL2BAN_MAXRETRY`  | Max retries before ban                   | `3`          |
| `FAIL2BAN_IGNOREIP`  | Ignore IP ranges (comma-separated)       | `127.0.0.1/8` |
| `TCPWRAPPERS_ENABLE` | Enable TCP Wrappers for vsftpd           | `YES`        |

### System Configuration

| Variable | Description | Default |
| -------- | ----------- | ------- |
| `TZ`     | Timezone    | `UTC`   |

## SSL Certificates

By default, the container generates a self-signed "snakeoil" certificate. For production use, mount your own certificates:

```bash
docker run -d \
  -v /path/to/cert.pem:/etc/ssl/certs/vsftpd.pem:ro \
  -v /path/to/key.pem:/etc/ssl/private/vsftpd.key:ro \
  -e RSA_CERT_FILE=/etc/ssl/certs/vsftpd.pem \
  -e RSA_PRIVATE_KEY_FILE=/etc/ssl/private/vsftpd.key \
  ghcr.io/karolkozlowski/vsftpd-containerized:latest
```

## Passive Mode Setup

For passive mode to work correctly behind NAT/firewall:

1. Set `PASV_ADDRESS` to your server's public IP address
2. Ensure ports `40000-40100` (or your custom range) are open in firewall
3. Configure port forwarding if behind NAT

## Building from Source

```bash
git clone https://github.com/karolkozlowski/vsftpd-containerized.git
cd vsftpd-containerized
docker build -t vsftpd .
```

## Security Considerations

- **Virtual Users**: Change default credentials (`guest`/`guest123`) immediately in production
- Always use strong passwords for LDAP bind credentials and FTP users
- Use SSL/TLS with valid certificates in production
- Restrict FTP access using `FTP_GROUP` environment variable (LDAP mode)
- Consider enabling fail2ban (default enabled) to mitigate brute force attempts
- Regularly update the container image for security patches
- Consider using SFTP instead of FTP for better security

## Troubleshooting

### Testing FTP Connection

```bash
# Test with lftp (supports SSL/TLS)
lftp -u username,password -e "set ssl:verify-certificate no; ls; bye" your-server.com

# Test without SSL (if SSL_ENABLE=NO)
lftp -u username,password -e "set ftp:ssl-allow no; ls; bye" your-server.com
```

### Virtual User Authentication Not Working

Ensure the virtual user system account exists. The container automatically creates it, but if you encounter issues:

```bash
docker exec vsftpd id vftp  # Should show user info
docker exec vsftpd cat /etc/vsftpd/virtual_users.passwd  # Should show htpasswd entries
```

## License

MIT License - see [LICENSE](LICENSE) file for details

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.
