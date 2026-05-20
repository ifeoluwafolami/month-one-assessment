#!/bin/bash
# Install and configure PostgreSQL on Amazon Linux 2

set -e
exec > /var/log/user_data.log 2>&1

echo "=== Starting Database Server Setup ==="
date

# Retry helper
retry_cmd() {
  local attempts="$1"
  local delay="$2"
  shift 2
  local n=1

  until "$@"; do
    if [ "$n" -ge "$attempts" ]; then
      echo "Command failed after ${attempts} attempts: $*"
      return 1
    fi
    echo "Attempt ${n}/${attempts} failed for: $*"
    n=$((n + 1))
    sleep "$delay"
  done
}

retry_cmd 10 15 yum makecache
retry_cmd 10 15 yum update -y

sed -i 's/^PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config
sed -i 's/^#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config
echo "PasswordAuthentication yes" >> /etc/ssh/sshd_config
systemctl restart sshd

# Create techcorp-admin user
useradd -m -s /bin/bash techcorp-admin 2>/dev/null || true
echo "techcorp-admin:TechC0rp@dmin2024!" | chpasswd
usermod -aG wheel techcorp-admin
echo "techcorp-admin ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers.d/techcorp-admin
chmod 0440 /etc/sudoers.d/techcorp-admin

amazon-linux-extras enable postgresql14
retry_cmd 10 15 yum install -y postgresql postgresql-server postgresql-contrib

postgresql-setup initdb

PG_HBA="/var/lib/pgsql/data/pg_hba.conf"
PG_CONF="/var/lib/pgsql/data/postgresql.conf"

cat > "$PG_HBA" <<'HBA'
# TYPE  DATABASE        USER            ADDRESS                 METHOD
local   all             postgres                                peer
local   all             all                                     md5
host    all             all             10.0.0.0/16             md5
host    all             all             127.0.0.1/32            md5
host    all             all             ::1/128                 md5
HBA

sed -i "s/#listen_addresses = 'localhost'/listen_addresses = '*'/" "$PG_CONF"
sed -i "s/#port = 5432/port = 5432/" "$PG_CONF"

sed -i "s/#log_timezone = 'GMT'/log_timezone = 'UTC'/" "$PG_CONF"
sed -i "s/#datestyle = 'iso, mdy'/datestyle = 'iso, mdy'/" "$PG_CONF"

systemctl start postgresql
systemctl enable postgresql

sleep 5

sudo -u postgres psql <<'PSQL'
-- Set postgres superuser password
ALTER USER postgres WITH PASSWORD 'P0stgr3s@dmin2024!';

-- Create application database
CREATE DATABASE techcorp_db
  WITH
  OWNER = postgres
  ENCODING = 'UTF8'
  LC_COLLATE = 'en_US.UTF-8'
  LC_CTYPE = 'en_US.UTF-8'
  TEMPLATE = template0;

-- Create application user
CREATE USER techcorp_app WITH
  LOGIN
  NOSUPERUSER
  NOCREATEDB
  NOCREATEROLE
  INHERIT
  NOREPLICATION
  CONNECTION LIMIT -1
  PASSWORD 'App@TechC0rp2024!';

-- Grant privileges
GRANT CONNECT ON DATABASE techcorp_db TO techcorp_app;
GRANT USAGE ON SCHEMA public TO techcorp_app;
GRANT CREATE ON SCHEMA public TO techcorp_app;

-- Connect to the application database and create a sample schema
\c techcorp_db

-- Grant schema access
GRANT ALL PRIVILEGES ON DATABASE techcorp_db TO techcorp_app;
GRANT ALL ON SCHEMA public TO techcorp_app;

-- Create a sample table to verify setup
CREATE TABLE IF NOT EXISTS health_check (
  id          SERIAL PRIMARY KEY,
  checked_at  TIMESTAMP DEFAULT NOW(),
  status      TEXT DEFAULT 'OK'
);

INSERT INTO health_check (status) VALUES ('Database initialized successfully');

-- Grant table access to app user
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO techcorp_app;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO techcorp_app;

\q
PSQL

TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" \
  -H "X-aws-ec2-metadata-token-ttl-seconds: 21600" 2>/dev/null || echo "")

if [ -n "$TOKEN" ]; then
  INSTANCE_ID=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" \
    http://169.254.169.254/latest/meta-data/instance-id 2>/dev/null || echo "unknown")
  AZ=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" \
    http://169.254.169.254/latest/meta-data/placement/availability-zone 2>/dev/null || echo "unknown")
else
  INSTANCE_ID="unknown"
  AZ="unknown"
fi

echo ""
echo "=== Database Server Setup Complete ==="
echo "Instance ID   : ${INSTANCE_ID}"
echo "AZ            : ${AZ}"
echo ""
echo "Connection details:"
echo "  Host        : $(hostname -I | awk '{print $1}')"
echo "  Port        : 5432"
echo "  Database    : techcorp_db"
echo "  App User    : techcorp_app"
echo "  PG Version  : $(psql --version)"
echo ""
echo "To connect (from web server or via bastion tunnel):"
echo "  psql -h <DB_PRIVATE_IP> -U techcorp_app -d techcorp_db"
echo ""
date
