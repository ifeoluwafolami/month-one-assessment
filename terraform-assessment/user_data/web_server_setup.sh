#!/bin/bash
# Install and configure Apache on Amazon Linux 2

set -e
exec > /var/log/user_data.log 2>&1

echo "=== Starting Web Server Setup ==="
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

retry_cmd 10 15 yum install -y httpd

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

TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" \
  -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")

INSTANCE_ID=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" \
  http://169.254.169.254/latest/meta-data/instance-id)

AZ=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" \
  http://169.254.169.254/latest/meta-data/placement/availability-zone)

PRIVATE_IP=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" \
  http://169.254.169.254/latest/meta-data/local-ipv4)

HOSTNAME=$(hostname)

cat > /var/www/html/index.html <<HTML
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>TechCorp Web Server</title>
  <style>
    * { box-sizing: border-box; margin: 0; padding: 0; }
    body {
      font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
      background: linear-gradient(135deg, #1a1a2e 0%, #16213e 50%, #0f3460 100%);
      color: #e0e0e0;
      min-height: 100vh;
      display: flex;
      align-items: center;
      justify-content: center;
    }
    .container {
      background: rgba(255,255,255,0.05);
      border: 1px solid rgba(255,255,255,0.1);
      border-radius: 16px;
      padding: 40px;
      max-width: 600px;
      width: 90%;
      backdrop-filter: blur(10px);
      box-shadow: 0 20px 60px rgba(0,0,0,0.5);
    }
    .logo {
      font-size: 2.5rem;
      font-weight: 800;
      background: linear-gradient(90deg, #00d2ff, #3a7bd5);
      -webkit-background-clip: text;
      -webkit-text-fill-color: transparent;
      margin-bottom: 8px;
    }
    .subtitle { color: #aaa; font-size: 1rem; margin-bottom: 32px; }
    .status-badge {
      display: inline-block;
      background: linear-gradient(90deg, #00b09b, #96c93d);
      color: #fff;
      padding: 4px 14px;
      border-radius: 20px;
      font-size: 0.8rem;
      font-weight: 600;
      margin-bottom: 28px;
      letter-spacing: 0.05em;
    }
    .info-grid {
      display: grid;
      gap: 12px;
    }
    .info-row {
      display: flex;
      justify-content: space-between;
      align-items: center;
      padding: 12px 16px;
      background: rgba(255,255,255,0.04);
      border-radius: 8px;
      border-left: 3px solid #3a7bd5;
    }
    .info-label { font-size: 0.85rem; color: #aaa; text-transform: uppercase; letter-spacing: 0.08em; }
    .info-value { font-size: 0.95rem; font-weight: 600; color: #fff; font-family: monospace; }
    .footer { margin-top: 28px; text-align: center; font-size: 0.8rem; color: #666; }
  </style>
</head>
<body>
  <div class="container">
    <div class="logo">TechCorp</div>
    <div class="subtitle">Web Application Infrastructure</div>
    <div class="status-badge">&#10003; SERVER HEALTHY</div>
    <div class="info-grid">
      <div class="info-row">
        <span class="info-label">Instance ID</span>
        <span class="info-value">${INSTANCE_ID}</span>
      </div>
      <div class="info-row">
        <span class="info-label">Availability Zone</span>
        <span class="info-value">${AZ}</span>
      </div>
      <div class="info-row">
        <span class="info-label">Private IP</span>
        <span class="info-value">${PRIVATE_IP}</span>
      </div>
      <div class="info-row">
        <span class="info-label">Hostname</span>
        <span class="info-value">${HOSTNAME}</span>
      </div>
      <div class="info-row">
        <span class="info-label">Server Software</span>
        <span class="info-value">Apache httpd (Amazon Linux 2)</span>
      </div>
    </div>
    <div class="footer">Served via AWS Application Load Balancer &bull; TechCorp &copy; 2024</div>
  </div>
</body>
</html>
HTML

cat > /var/www/html/health.html <<'HEALTH'
<!DOCTYPE html>
<html>
<head><title>Health Check</title></head>
<body><h1>OK</h1><p>Server is healthy</p></body>
</html>
HEALTH

systemctl start httpd
systemctl enable httpd

if systemctl is-active --quiet firewalld; then
  firewall-cmd --permanent --add-service=http
  firewall-cmd --permanent --add-service=https
  firewall-cmd --reload
fi

echo "=== Web Server Setup Complete ==="
echo "Instance ID : ${INSTANCE_ID}"
echo "AZ          : ${AZ}"
echo "Apache      : $(httpd -v | head -1)"
date
