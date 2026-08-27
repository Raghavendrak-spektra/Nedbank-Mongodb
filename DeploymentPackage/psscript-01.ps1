Param(
    [string]$AzureUserName,
    [string]$AzurePassword,
    [string]$AzureTenantID,
    [string]$AzureSubscriptionID,
    [string]$ODLID,
    [string]$InstallCloudLabsShadow,
    [string]$DeploymentID,
    [string]$vmAdminUsername,
    [string]$vmAdminPassword,
    [string]$trainerUserName,
    [string]$trainerUserPassword
)

$ErrorActionPreference = 'Stop'

try {
    New-Item -ItemType Directory -Path 'C:\WindowsAzure\Logs' -Force | Out-Null
    Start-Transcript -Path 'C:\WindowsAzure\Logs\CloudLabsCustomScriptExtension.txt' -Append -Force
}
catch {
    New-Item -ItemType Directory -Path '/var/log/cloudlabs' -Force | Out-Null
    Start-Transcript -Path '/var/log/cloudlabs/CloudLabsCustomScriptExtension.txt' -Append -Force
}

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

function Write-Log {
    param([string]$Message)
    Write-Host "[$(Get-Date -Format o)] $Message"
}

function Invoke-LocalBash {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ScriptText
    )

    $scriptPath = "/tmp/cloudlabs-mongodb-cse-$([guid]::NewGuid().ToString('N')).sh"
    Set-Content -Path $scriptPath -Value $ScriptText -Encoding UTF8
    & /bin/bash $scriptPath
    $exitCode = $LASTEXITCODE
    Remove-Item -Path $scriptPath -Force -ErrorAction SilentlyContinue
    if ($exitCode -ne 0) {
        throw "Bash bootstrap step failed with exit code $exitCode."
    }
}

function Update-CredContent {
    param([string]$Content)

    $lt = [char]60
    $gt = [char]62
    $replacements = @{
        'GET-AZUSER-UPN' = $AzureUserName
        'GET-AZUSER-PASSWORD' = $AzurePassword
        'GET-AZURE-TENANT-ID' = $AzureTenantID
        'GET-AZURE-SUBSCRIPTION-ID' = $AzureSubscriptionID
        'GET-ODL-ID' = $ODLID
        'GET-DEPLOYMENT-ID' = $DeploymentID
        ($lt + 'AzureUserName' + $gt) = $AzureUserName
        ($lt + 'AzurePassword' + $gt) = $AzurePassword
        ($lt + 'AzureTenantID' + $gt) = $AzureTenantID
        ($lt + 'AzureSubscriptionID' + $gt) = $AzureSubscriptionID
        ($lt + 'ODLID' + $gt) = $ODLID
        ($lt + 'DeploymentID' + $gt) = $DeploymentID
        '__AzureUserName__' = $AzureUserName
        '__AzurePassword__' = $AzurePassword
        '__AzureTenantID__' = $AzureTenantID
        '__AzureSubscriptionID__' = $AzureSubscriptionID
        '__ODLID__' = $ODLID
        '__DeploymentID__' = $DeploymentID
    }

    foreach ($key in $replacements.Keys) {
        $Content = $Content.Replace($key, [string]$replacements[$key])
    }

    return $Content
}

function CreateCredFile {
    Write-Log 'Creating CloudLabs credential files from cloudlabs-common assets.'

    $commonBase = 'https://experienceazure.blob.core.windows.net/templates/cloudlabs-common'
    $downloadRoot = if ($IsWindows) { 'C:\CloudLabs\Downloads' } else { '/opt/cloudlabs/downloads' }
    New-Item -ItemType Directory -Path $downloadRoot -Force | Out-Null

    $files = @('AzureCreds.txt', 'AzureCreds.ps1')
    foreach ($file in $files) {
        $uri = "$commonBase/$file"
        $target = Join-Path $downloadRoot $file
        try {
            Invoke-WebRequest -Uri $uri -OutFile $target -UseBasicParsing -ErrorAction Stop
            $content = Get-Content -Path $target -Raw -ErrorAction Stop
            Set-Content -Path $target -Value (Update-CredContent -Content $content) -Encoding UTF8
        }
        catch {
            Write-Log "Could not download $uri. Creating local fallback $file. Error: $($_.Exception.Message)"
            if ($file -eq 'AzureCreds.txt') {
                $fallback = @"
Azure Username: $AzureUserName
Azure Password: $AzurePassword
Tenant ID: $AzureTenantID
Subscription ID: $AzureSubscriptionID
ODL ID: $ODLID
Deployment ID: $DeploymentID
"@
                Set-Content -Path $target -Value $fallback -Encoding UTF8
            }
            else {
                $fallback = @"
`$AzureUserName = '$AzureUserName'
`$AzurePassword = '$AzurePassword'
`$AzureTenantID = '$AzureTenantID'
`$AzureSubscriptionID = '$AzureSubscriptionID'
`$ODLID = '$ODLID'
`$DeploymentID = '$DeploymentID'
"@
                Set-Content -Path $target -Value $fallback -Encoding UTF8
            }
        }
    }

    $destinations = @()
    if ($IsWindows) {
        $destinations += 'C:\LabFiles'
        $destinations += 'C:\Users\Public\Desktop'
    }
    else {
        $destinations += '/opt/cloudlabs/credentials'
        if (-not [string]::IsNullOrWhiteSpace($vmAdminUsername)) {
            $destinations += "/home/$vmAdminUsername/LabFiles"
            $destinations += "/home/$vmAdminUsername/Desktop"
        }
    }

    foreach ($destination in $destinations) {
        New-Item -ItemType Directory -Path $destination -Force | Out-Null
        foreach ($file in $files) {
            Copy-Item -Path (Join-Path $downloadRoot $file) -Destination (Join-Path $destination $file) -Force
        }
    }
}

try {
    Write-Log 'Starting MongoDB Customer Data Fundamentals Stage 1 bootstrap.'
    Write-Log "DeploymentID=$DeploymentID; ODLID=$ODLID; Subscription=$AzureSubscriptionID"

    CreateCredFile

    $env:CLOUDLABS_TRAINER_USERNAME = $trainerUserName
    $env:CLOUDLABS_TRAINER_PASSWORD = $trainerUserPassword
    $env:CLOUDLABS_INSTALL_SHADOW = $InstallCloudLabsShadow
    $env:CLOUDLABS_VM_ADMIN_USERNAME = $vmAdminUsername

    Invoke-LocalBash -ScriptText @'
set -euo pipefail

log() {
  echo "[$(date --iso-8601=seconds)] $*"
}

export DEBIAN_FRONTEND=noninteractive
WORK_ROOT="/opt/cloudlabs/mongodb-customer-data"
DATA_DIR="${WORK_ROOT}/data"
SCRIPTS_DIR="${WORK_ROOT}/scripts"
BACKUPS_DIR="${WORK_ROOT}/backups"
EVIDENCE_DIR="${WORK_ROOT}/evidence"
RESET_DIR="${WORK_ROOT}/reset"
DOWNLOAD_DIR="/opt/cloudlabs/downloads"

log "Preparing Linux user and workspace directories."
mkdir -p "$WORK_ROOT" "$DATA_DIR" "$SCRIPTS_DIR" "$BACKUPS_DIR" "$EVIDENCE_DIR" "$RESET_DIR" "$DOWNLOAD_DIR"

if [ "${CLOUDLABS_INSTALL_SHADOW:-true}" != "false" ] && [ -n "${CLOUDLABS_TRAINER_USERNAME:-}" ] && [ -n "${CLOUDLABS_TRAINER_PASSWORD:-}" ]; then
  if ! id "${CLOUDLABS_TRAINER_USERNAME}" >/dev/null 2>&1; then
    useradd -m -s /bin/bash "${CLOUDLABS_TRAINER_USERNAME}"
  fi
  echo "${CLOUDLABS_TRAINER_USERNAME}:${CLOUDLABS_TRAINER_PASSWORD}" | chpasswd
  usermod -aG sudo "${CLOUDLABS_TRAINER_USERNAME}" || true
  usermod -aG adm "${CLOUDLABS_TRAINER_USERNAME}" || true
  log "Trainer/instructor local Linux account configured for remote support."
fi

log "Installing prerequisite packages and MongoDB Community Server 7.0."
apt-get update -y
apt-get install -y curl ca-certificates gnupg lsb-release jq python3 python3-pip openssl software-properties-common

install -d -m 0755 /usr/share/keyrings
if [ ! -s /usr/share/keyrings/mongodb-server-7.0.gpg ]; then
  curl -fsSL https://pgp.mongodb.com/server-7.0.asc | gpg --dearmor -o /usr/share/keyrings/mongodb-server-7.0.gpg
  chmod 0644 /usr/share/keyrings/mongodb-server-7.0.gpg
fi

ARCHITECTURE="$(dpkg --print-architecture)"
case "$ARCHITECTURE" in
  amd64|arm64) ;;
  *) log "Unsupported architecture reported by dpkg: $ARCHITECTURE"; exit 11 ;;
esac

echo "deb [ arch=${ARCHITECTURE} signed-by=/usr/share/keyrings/mongodb-server-7.0.gpg ] https://repo.mongodb.org/apt/ubuntu jammy/mongodb-org/7.0 multiverse" > /etc/apt/sources.list.d/mongodb-org-7.0.list
apt-get update -y
apt-get install -y mongodb-org mongodb-database-tools

systemctl daemon-reload
systemctl enable mongod
systemctl restart mongod

for i in $(seq 1 30); do
  if mongosh --quiet --eval 'db.adminCommand({ ping: 1 }).ok' >/tmp/mongodb-ping.out 2>&1; then
    if grep -q '^1$' /tmp/mongodb-ping.out; then
      break
    fi
  fi
  sleep 2
  if [ "$i" -eq 30 ]; then
    log "MongoDB did not respond to ping."
    cat /tmp/mongodb-ping.out || true
    systemctl status mongod --no-pager || true
    exit 12
  fi
done
rm -f /tmp/mongodb-ping.out

log "Writing deterministic customer360 seed script."
cat > "${DATA_DIR}/seed-customer360.js" <<'MONGOSEED'
const dbName = "customer360";
const cdb = db.getSiblingDB(dbName);

cdb.customers.drop();
cdb.orders.drop();
cdb.audit_events.drop();

const regions = ["North", "South", "East", "West", "Central"];
const loyaltyTiers = ["Bronze", "Silver", "Gold", "Platinum"];
const statuses = ["active", "active", "active", "inactive"];
const productCategories = ["Electronics", "Home", "Apparel", "Books", "Beauty", "Sports", "Toys", "Grocery"];
const orderStatuses = ["placed", "paid", "shipped", "delivered", "cancelled", "returned"];
const firstNames = ["Avery", "Jordan", "Taylor", "Morgan", "Riley", "Casey", "Jamie", "Drew", "Quinn", "Skyler"];
const lastNames = ["Adams", "Baker", "Chen", "Diaz", "Evans", "Garcia", "Harris", "Ivanov", "Jones", "Khan"];

const customers = [];
for (let i = 1; i <= 1000; i++) {
  const region = regions[i % regions.length];
  const tier = loyaltyTiers[i % loyaltyTiers.length];
  const status = statuses[i % statuses.length];
  const firstName = firstNames[i % firstNames.length];
  const lastName = lastNames[(i * 3) % lastNames.length];
  const createdAt = new Date(Date.UTC(2023, i % 12, (i % 28) + 1, 9, 0, 0));
  customers.push({
    customerId: "CUST-" + String(i).padStart(4, "0"),
    firstName,
    lastName,
    email: `customer${String(i).padStart(4, "0")}@contoso-retail.example`,
    phone: `+1-555-${String(1000000 + i).slice(1)}`,
    region,
    loyaltyTier: tier,
    status,
    createdAt,
    updatedAt: createdAt,
    consent: {
      marketing: i % 3 !== 0,
      supportContact: i % 5 !== 0
    },
    profile: {
      preferredChannel: ["email", "sms", "phone", "chat"][i % 4],
      lifetimeValueBand: ["low", "medium", "high"][i % 3]
    },
    address: {
      city: ["Seattle", "Austin", "Boston", "Denver", "Phoenix"][i % 5],
      country: "US"
    }
  });
}

cdb.customers.insertMany(customers, { ordered: true });

const orders = [];
for (let i = 1; i <= 5000; i++) {
  const customerNumber = ((i * 37) % 1000) + 1;
  const customer = customers[customerNumber - 1];
  const category = productCategories[i % productCategories.length];
  const quantity = (i % 4) + 1;
  const base = 15 + ((i * 19) % 240);
  const total = Number((base * quantity + ((i % 17) * 0.49)).toFixed(2));
  const orderDate = new Date(Date.UTC(2024, i % 12, (i % 28) + 1, (i % 24), i % 60, 0));
  orders.push({
    orderId: "ORD-" + String(i).padStart(5, "0"),
    customerId: customer.customerId,
    customerEmail: customer.email,
    region: customer.region,
    loyaltyTier: customer.loyaltyTier,
    orderDate,
    status: orderStatuses[i % orderStatuses.length],
    productCategory: category,
    channel: ["web", "mobile", "store", "support-assisted"][i % 4],
    itemCount: quantity,
    total,
    currency: "USD",
    supportFlag: i % 41 === 0,
    items: [
      {
        sku: `SKU-${category.substring(0, 3).toUpperCase()}-${String(i % 250).padStart(3, "0")}`,
        category,
        quantity,
        unitPrice: Number((total / quantity).toFixed(2))
      }
    ]
  });
}

for (let start = 0; start < orders.length; start += 500) {
  cdb.orders.insertMany(orders.slice(start, start + 500), { ordered: true });
}

cdb.audit_events.insertOne({
  module: "bootstrap",
  eventType: "seed-created",
  operator: "cloudlabs-cse",
  note: "Initial customer360 retail dataset created with 1000 customers and 5000 orders.",
  createdAt: new Date()
});

cdb.customers.createIndex({ customerId: 1 }, { unique: true, name: "ux_customerId" });
cdb.customers.createIndex({ email: 1 }, { unique: true, name: "ux_email" });
cdb.orders.createIndex({ customerId: 1 }, { name: "ix_orders_customerId" });
cdb.audit_events.createIndex({ module: 1, eventType: 1, createdAt: -1 }, { name: "ix_audit_module_event_created" });

printjson({
  database: dbName,
  customers: cdb.customers.countDocuments(),
  orders: cdb.orders.countDocuments(),
  audit_events: cdb.audit_events.countDocuments()
});
MONGOSEED

mongosh --quiet "${DATA_DIR}/seed-customer360.js" | tee "${EVIDENCE_DIR}/bootstrap-seed-output.json"

log "Creating environment file with local MongoDB connection values."
cat > "${WORK_ROOT}/.env" <<'ENVFILE'
MONGODB_URI=mongodb://127.0.0.1:27017/customer360
MONGODB_HOST=127.0.0.1
MONGODB_PORT=27017
MONGODB_DATABASE=customer360
MONGODB_AUTH_MODE=disabled
LAB_WORKSPACE=/opt/cloudlabs/mongodb-customer-data
ENVFILE
chmod 0644 "${WORK_ROOT}/.env"

log "Creating helper, reset, incident, and evidence scaffolding scripts."
cat > "${SCRIPTS_DIR}/module2-backup-example.sh" <<'BACKUP'
#!/usr/bin/env bash
set -euo pipefail
WORK_ROOT="/opt/cloudlabs/mongodb-customer-data"
BACKUP_ROOT="${WORK_ROOT}/backups"
EVIDENCE_ROOT="${WORK_ROOT}/evidence"
STAMP="$(date +%Y%m%d-%H%M%S)"
TARGET="${BACKUP_ROOT}/customer360-${STAMP}"
mkdir -p "$TARGET" "$EVIDENCE_ROOT"
mongosh customer360 --quiet --eval 'printjson({ customers: db.customers.countDocuments(), orders: db.orders.countDocuments() })' | tee "${EVIDENCE_ROOT}/m2-pre-backup-counts.json"
mongodump --db customer360 --out "$TARGET"
echo "Backup created at $TARGET"
BACKUP
chmod +x "${SCRIPTS_DIR}/module2-backup-example.sh"

cat > "${SCRIPTS_DIR}/module3-slow-query-example.js" <<'M3SLOW'
const cdb = db.getSiblingDB("customer360");
const query = {
  region: "West",
  orderDate: { $gte: ISODate("2024-01-01T00:00:00Z") },
  status: "delivered"
};
printjson(cdb.orders.find(query).sort({ orderDate: -1 }).explain("executionStats"));
M3SLOW
chmod 0644 "${SCRIPTS_DIR}/module3-slow-query-example.js"

cat > "${SCRIPTS_DIR}/module4-analytics-template.mongodb.js" <<'M4TEMPLATE'
const cdb = db.getSiblingDB("customer360");
// Copy this template to analytics-report.mongodb.js and adapt it for your required report.
const results = cdb.orders.aggregate([
  { $match: { status: { $in: ["paid", "shipped", "delivered"] } } },
  { $group: { _id: "$region", orderCount: { $sum: 1 }, totalRevenue: { $sum: "$total" }, averageOrderValue: { $avg: "$total" } } },
  { $project: { _id: 0, region: "$_id", orderCount: 1, totalRevenue: { $round: ["$totalRevenue", 2] }, averageOrderValue: { $round: ["$averageOrderValue", 2] } } },
  { $sort: { totalRevenue: -1 } }
]).toArray();
printjson(results);
M4TEMPLATE
chmod 0644 "${SCRIPTS_DIR}/module4-analytics-template.mongodb.js"

cat > "${SCRIPTS_DIR}/module5-enable-auth.sh" <<'M5ENABLE'
#!/usr/bin/env bash
set -euo pipefail
CONF="/etc/mongod.conf"
sudo cp "$CONF" "${CONF}.preauth.$(date +%Y%m%d-%H%M%S)"
sudo python3 - <<'PY'
from pathlib import Path
path = Path('/etc/mongod.conf')
lines = path.read_text().splitlines()
out = []
in_security = False
saw_security = False
wrote_authorization = False
for line in lines:
    stripped = line.strip()
    top_level_key = bool(stripped.endswith(':') and not line.startswith((' ', '\t')))
    if top_level_key:
        if in_security and not wrote_authorization:
            out.append('  authorization: enabled')
            wrote_authorization = True
        in_security = stripped == 'security:'
        if in_security:
            saw_security = True
    if in_security and stripped.startswith('authorization:'):
        out.append('  authorization: enabled')
        wrote_authorization = True
        continue
    out.append(line)
if in_security and not wrote_authorization:
    out.append('  authorization: enabled')
if not saw_security:
    if out and out[-1].strip():
        out.append('')
    out.extend(['security:', '  authorization: enabled'])
path.write_text('\n'.join(out) + '\n')
PY
sudo systemctl restart mongod
systemctl is-active mongod
M5ENABLE
chmod +x "${SCRIPTS_DIR}/module5-enable-auth.sh"

cat > "${SCRIPTS_DIR}/module5-disable-auth.sh" <<'M5DISABLE'
#!/usr/bin/env bash
set -euo pipefail
sudo python3 - <<'PY'
from pathlib import Path
path = Path('/etc/mongod.conf')
if path.exists():
    lines = path.read_text().splitlines()
    out = []
    for line in lines:
        if line.strip().startswith('authorization:'):
            out.append('  authorization: disabled')
        else:
            out.append(line)
    path.write_text('\n'.join(out) + '\n')
PY
sudo systemctl restart mongod
systemctl is-active mongod
M5DISABLE
chmod +x "${SCRIPTS_DIR}/module5-disable-auth.sh"

cat > "${SCRIPTS_DIR}/module6-inject-stopped-disabled-mongod.sh" <<'M6FAULT'
#!/usr/bin/env bash
set -euo pipefail
echo "Injecting Module 6 incident: stopping and disabling mongod."
sudo systemctl stop mongod
sudo systemctl disable mongod
systemctl is-active mongod || true
systemctl is-enabled mongod || true
M6FAULT
chmod +x "${SCRIPTS_DIR}/module6-inject-stopped-disabled-mongod.sh"

cat > "${SCRIPTS_DIR}/module6-recover-mongod.sh" <<'M6RECOVER'
#!/usr/bin/env bash
set -euo pipefail
echo "Recovering mongod service: enabling and starting."
sudo systemctl enable mongod
sudo systemctl start mongod
systemctl is-active mongod
systemctl is-enabled mongod
mongosh customer360 --quiet --eval 'printjson({ customers: db.customers.countDocuments(), orders: db.orders.countDocuments() })'
M6RECOVER
chmod +x "${SCRIPTS_DIR}/module6-recover-mongod.sh"

cat > "${SCRIPTS_DIR}/create-atlas-evidence-template.sh" <<'M7TEMPLATE'
#!/usr/bin/env bash
set -euo pipefail
TARGET="/opt/cloudlabs/mongodb-customer-data/evidence/atlas-operations-evidence.txt"
if [ -e "$TARGET" ]; then
  echo "$TARGET already exists. Not overwriting learner evidence."
  exit 0
fi
cat > "$TARGET" <<'EOF'
Atlas Project Name: customer360-lab
Atlas Cluster Name: customer360-atlas-lab
Connection Method Used: Atlas UI, mongosh, or Compass
Network Access Approach: temporary client IP allowlist
Database Access Role Observed: readWrite on customer360
Sample Data Action: imported sample dataset or created representative collection
Security Setting Reviewed: database access user and network access settings
Monitoring Metric Reviewed: operations or connections metric
Backup Setting Observed: backup option reviewed in Atlas UI
Troubleshooting Note: documented one non-secret observation without connection strings
Secrets Stored: No
EOF
chmod 0664 "$TARGET"
echo "Created $TARGET. Edit the sample values before validation. Do not store passwords, API keys, or full connection strings."
M7TEMPLATE
chmod +x "${SCRIPTS_DIR}/create-atlas-evidence-template.sh"

cat > "${DATA_DIR}/atlas-operations-evidence.template.txt" <<'M7DATA'
Atlas Project Name: customer360-lab
Atlas Cluster Name: customer360-atlas-lab
Connection Method Used: Atlas UI, mongosh, or Compass
Network Access Approach: temporary client IP allowlist
Database Access Role Observed: readWrite on customer360
Sample Data Action: imported sample dataset or created representative collection
Security Setting Reviewed: database access user and network access settings
Monitoring Metric Reviewed: operations or connections metric
Backup Setting Observed: backup option reviewed in Atlas UI
Troubleshooting Note: documented one non-secret observation without connection strings
Secrets Stored: No
M7DATA
chmod 0644 "${DATA_DIR}/atlas-operations-evidence.template.txt"

cat > "${RESET_DIR}/disable-auth.sh" <<'RESETAUTH'
#!/usr/bin/env bash
set -euo pipefail
/opt/cloudlabs/mongodb-customer-data/scripts/module5-disable-auth.sh
RESETAUTH
chmod +x "${RESET_DIR}/disable-auth.sh"

cat > "${RESET_DIR}/reset-dataset.sh" <<'RESETDATA'
#!/usr/bin/env bash
set -euo pipefail
WORK_ROOT="/opt/cloudlabs/mongodb-customer-data"
# Ensure the assessment returns to the initial unauthenticated state before reseeding.
"${WORK_ROOT}/scripts/module5-disable-auth.sh" >/dev/null 2>&1 || true
sudo systemctl enable mongod >/dev/null
sudo systemctl start mongod
mongosh --quiet "${WORK_ROOT}/data/seed-customer360.js"
echo "customer360 dataset reset to initial seed state."
RESETDATA
chmod +x "${RESET_DIR}/reset-dataset.sh"

cat > "${RESET_DIR}/clear-backups-evidence.sh" <<'RESETCLEAN'
#!/usr/bin/env bash
set -euo pipefail
WORK_ROOT="/opt/cloudlabs/mongodb-customer-data"
find "${WORK_ROOT}/backups" -mindepth 1 -maxdepth 1 -exec rm -rf {} +
find "${WORK_ROOT}/evidence" -mindepth 1 -maxdepth 1 -type f ! -name 'bootstrap-seed-output.json' -delete
find "${WORK_ROOT}/evidence" -mindepth 1 -maxdepth 1 -type d -exec rm -rf {} +
echo "Backup and evidence folders cleared."
RESETCLEAN
chmod +x "${RESET_DIR}/clear-backups-evidence.sh"

cat > "${RESET_DIR}/recover-service.sh" <<'RESETSVC'
#!/usr/bin/env bash
set -euo pipefail
/opt/cloudlabs/mongodb-customer-data/scripts/module6-recover-mongod.sh
RESETSVC
chmod +x "${RESET_DIR}/recover-service.sh"

cat > "${WORK_ROOT}/README.txt" <<'README'
MongoDB Customer Data Fundamentals lab workspace

Primary database: customer360
Collections: customers, orders, audit_events

Key folders:
- data: seed files and non-secret templates
- scripts: optional helper scripts and exercise templates
- backups: learner-created backup artifacts
- evidence: learner-created validation evidence
- reset: reset and recovery helpers

MongoDB starts without authentication for Modules 1-4. Module 5 enables authorization after you create the required users. Do not store passwords, Atlas API keys, private keys, or full connection strings in evidence files.
README
chmod 0644 "${WORK_ROOT}/README.txt"

cat > /etc/profile.d/cloudlabs-mongodb-customer-data.sh <<'PROFILE'
export C360_LAB_HOME=/opt/cloudlabs/mongodb-customer-data
alias c360='cd /opt/cloudlabs/mongodb-customer-data'
PROFILE
chmod 0644 /etc/profile.d/cloudlabs-mongodb-customer-data.sh

cat > "${EVIDENCE_DIR}/bootstrap-status.json" <<EOF
{
  "status": "completed",
  "database": "customer360",
  "customersSeeded": 1000,
  "ordersSeeded": 5000,
  "authenticationInitialState": "disabled",
  "workspace": "${WORK_ROOT}",
  "createdAtUtc": "$(date -u --iso-8601=seconds)"
}
EOF
chmod 0644 "${EVIDENCE_DIR}/bootstrap-status.json"

# Keep MongoDB bound locally for the lab VM and ensure authorization starts disabled.
if grep -Eq '^[[:space:]]*authorization:[[:space:]]*enabled[[:space:]]*$' /etc/mongod.conf; then
  "${SCRIPTS_DIR}/module5-disable-auth.sh" >/dev/null || true
fi
sudo sed -i 's/^[[:space:]]*bindIp:[[:space:]].*/  bindIp: 127.0.0.1/' /etc/mongod.conf || true
systemctl restart mongod
systemctl enable mongod

log "Running final MongoDB bootstrap verification."
COUNTS_OUTPUT=$(mongosh customer360 --quiet --eval 'print("customers=" + db.customers.countDocuments() + ";orders=" + db.orders.countDocuments() + ";audit_events=" + db.audit_events.countDocuments())')
echo "$COUNTS_OUTPUT" | tee "${EVIDENCE_DIR}/bootstrap-final-counts.txt"

echo "$COUNTS_OUTPUT" | grep -q 'customers=1000;orders=5000' || { log "Unexpected final counts: $COUNTS_OUTPUT"; exit 13; }

if [ -n "${CLOUDLABS_VM_ADMIN_USERNAME:-}" ] && id "${CLOUDLABS_VM_ADMIN_USERNAME}" >/dev/null 2>&1; then
  chown -R "${CLOUDLABS_VM_ADMIN_USERNAME}:${CLOUDLABS_VM_ADMIN_USERNAME}" "$WORK_ROOT"
  mkdir -p "/home/${CLOUDLABS_VM_ADMIN_USERNAME}/Desktop" "/home/${CLOUDLABS_VM_ADMIN_USERNAME}/LabFiles"
  ln -sfn "$WORK_ROOT" "/home/${CLOUDLABS_VM_ADMIN_USERNAME}/mongodb-customer-data"
  chown -h "${CLOUDLABS_VM_ADMIN_USERNAME}:${CLOUDLABS_VM_ADMIN_USERNAME}" "/home/${CLOUDLABS_VM_ADMIN_USERNAME}/mongodb-customer-data" || true
fi
chmod -R u+rwX,g+rwX,o+rX "$WORK_ROOT"
chmod -R a+w "$BACKUPS_DIR" "$EVIDENCE_DIR" "$SCRIPTS_DIR"

log "MongoDB Customer Data Fundamentals bootstrap completed successfully."
'@

    Write-Log 'Stage 1 bootstrap completed successfully.'
}
catch {
    Write-Host "Bootstrap failed: $($_.Exception.Message)"
    Write-Host $_.ScriptStackTrace
    throw
}
finally {
    try { Stop-Transcript | Out-Null } catch { }
}
