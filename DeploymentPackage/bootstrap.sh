#!/usr/bin/env bash

set -euo pipefail

export DEBIAN_FRONTEND=noninteractive

# ============================================================
# MongoDB — Dashboard Query Performance
# Ubuntu 22.04
# MongoDB 7.0
#
# Seeds the branchops banking dataset used by the
# branch-performance dashboard assessment:
#   - 40   branches
#   - 20000 transactions (deliberately unindexed for the
#           dashboard query so the baseline is a COLLSCAN)
#   - audit_events
# ============================================================

# ------------------------------------------------------------
# Paths
# ------------------------------------------------------------
LAB_USER="AssessmentUser"
WORK_ROOT="/home/${LAB_USER}/mongodb-dashboard"
DATA_DIR="${WORK_ROOT}/data"
SCRIPTS_DIR="${WORK_ROOT}/scripts"
EVIDENCE_DIR="${WORK_ROOT}/evidence"
RESET_DIR="${WORK_ROOT}/reset"

SEED_SCRIPT="${DATA_DIR}/seed-branchops.js"

LOG_DIR="/var/log/cloudlabs"
BOOTSTRAP_LOG="${LOG_DIR}/mongodb-dashboard-bootstrap.log"

# ------------------------------------------------------------
# Logging
# ------------------------------------------------------------

mkdir -p "$LOG_DIR"
touch "$BOOTSTRAP_LOG"

exec > >(tee -a "$BOOTSTRAP_LOG") 2>&1

log() {
    echo "[$(date -u '+%Y-%m-%dT%H:%M:%SZ')] $*"
}

log "=========================================="
log "MongoDB — Dashboard Query Performance"
log "Bootstrap started"
log "=========================================="

# ------------------------------------------------------------
# Detect the interactive lab user (first uid>=1000 login user)
# ------------------------------------------------------------

LAB_USER="$(getent passwd | awk -F: '$3 >= 1000 && $7 ~ /(bash|sh)$/ { print $1; exit }')"

if [ -z "$LAB_USER" ]; then
    log "WARNING: No interactive lab user detected. Workspace symlink will be skipped."
else
    log "Detected lab user: $LAB_USER"
fi

# ------------------------------------------------------------
# Create learner workspace
# ------------------------------------------------------------

log "Creating learner workspace"

mkdir -p "$WORK_ROOT" "$DATA_DIR" "$SCRIPTS_DIR" "$EVIDENCE_DIR" "$RESET_DIR"

# ------------------------------------------------------------
# Install prerequisites
# ------------------------------------------------------------

log "Installing prerequisite packages"

# Fix for Ubuntu command-not-found database update issue
rm -f /etc/apt/apt.conf.d/50command-not-found

apt-get update -y

apt-get install -y \
    ca-certificates \
    curl \
    gnupg \
    jq

# ------------------------------------------------------------
# Configure MongoDB 7.0 repository
# ------------------------------------------------------------

log "Configuring MongoDB 7.0 repository"

rm -f /etc/apt/sources.list.d/mongodb-org-7.0.list
rm -f /usr/share/keyrings/mongodb-server-7.0.gpg

curl -fsSL \
    https://pgp.mongodb.com/server-7.0.asc \
    | gpg --dearmor \
    -o /usr/share/keyrings/mongodb-server-7.0.gpg

chmod 644 /usr/share/keyrings/mongodb-server-7.0.gpg

ARCHITECTURE="$(dpkg --print-architecture)"

case "$ARCHITECTURE" in
    amd64|arm64) ;;
    *)
        log "ERROR: Unsupported architecture: $ARCHITECTURE"
        exit 11
        ;;
esac

cat > /etc/apt/sources.list.d/mongodb-org-7.0.list <<EOF
deb [ arch=${ARCHITECTURE} signed-by=/usr/share/keyrings/mongodb-server-7.0.gpg ] https://repo.mongodb.org/apt/ubuntu jammy/mongodb-org/7.0 multiverse
EOF

apt-get update -y

# ------------------------------------------------------------
# Install MongoDB
# ------------------------------------------------------------

log "Installing MongoDB"

apt-get install -y mongodb-org mongodb-database-tools

# ------------------------------------------------------------
# Configure MongoDB (localhost only for this single-VM lab)
# ------------------------------------------------------------

log "Configuring MongoDB"

MONGOD_CONF="/etc/mongod.conf"

if [ ! -f "$MONGOD_CONF" ]; then
    log "ERROR: $MONGOD_CONF was not created."
    exit 1
fi

sed -i '/^[[:space:]]*bindIp:/d' "$MONGOD_CONF"

if grep -q '^net:' "$MONGOD_CONF"; then
    sed -i '/^net:/a\  bindIp: 127.0.0.1' "$MONGOD_CONF"
else
    cat >> "$MONGOD_CONF" <<'EOF'

net:
  port: 27017
  bindIp: 127.0.0.1
EOF
fi

# ------------------------------------------------------------
# Start MongoDB
# ------------------------------------------------------------

log "Starting MongoDB"

systemctl daemon-reload
systemctl enable mongod
systemctl restart mongod

# ------------------------------------------------------------
# Wait for MongoDB
# ------------------------------------------------------------

log "Waiting for MongoDB to become available"

MONGO_READY="false"

for i in $(seq 1 60); do
    if mongosh \
        --host 127.0.0.1 \
        --port 27017 \
        --quiet \
        --eval 'db.adminCommand({ ping: 1 }).ok' 2>/dev/null \
        | grep -q '^1$'; then

        MONGO_READY="true"
        break
    fi

    sleep 2
done

if [ "$MONGO_READY" != "true" ]; then
    log "ERROR: MongoDB did not become available."
    systemctl status mongod --no-pager || true
    journalctl -u mongod --no-pager -n 100 || true
    exit 1
fi

log "MongoDB is ready"

MONGO_VERSION="$(
    mongosh --host 127.0.0.1 --port 27017 --quiet --eval 'db.version()'
)"

log "MongoDB version: $MONGO_VERSION"

# ------------------------------------------------------------
# Write the deterministic branchops seed script
# ------------------------------------------------------------

log "Writing branchops seed script"

cat > "$SEED_SCRIPT" <<'MONGOSEED'
const dbName = "branchops";
const bdb = db.getSiblingDB(dbName);

print("Using database: " + bdb.getName());
print("Dropping existing collections...");

bdb.branches.drop();
bdb.transactions.drop();
bdb.audit_events.drop();
bdb.dashboard_meta.drop();

const provinces = [
    "Gauteng",
    "Western Cape",
    "KwaZulu-Natal",
    "Eastern Cape",
    "Free State",
    "Limpopo",
    "Mpumalanga",
    "North West",
    "Northern Cape"
];

const cities = [
    "Johannesburg",
    "Cape Town",
    "Durban",
    "Gqeberha",
    "Bloemfontein",
    "Polokwane",
    "Mbombela",
    "Rustenburg",
    "Kimberley",
    "Pretoria"
];

const txnTypes = ["deposit", "withdrawal", "transfer", "billpayment"];
const channels = ["branch", "atm", "online", "mobile"];

// ~70% completed so the dashboard query has a rich result set.
const txnStatuses = [
    "completed", "completed", "completed", "completed",
    "completed", "completed", "completed",
    "pending", "failed", "reversed"
];

print("Generating 40 branches...");

const branches = [];

for (let i = 1; i <= 40; i++) {
    const padded = String(i).padStart(3, "0");

    branches.push({
        branchCode: "BR-" + padded,
        name: "Nedbank Branch " + padded,
        region: provinces[(i - 1) % provinces.length],
        city: cities[(i - 1) % cities.length],
        openedAt: new Date(Date.UTC(2015 + (i % 8), (i - 1) % 12, ((i - 1) % 27) + 1)),
        active: true
    });
}

bdb.branches.insertMany(branches, { ordered: true });
print("Inserted branches: " + bdb.branches.countDocuments());

print("Generating 20000 transactions...");

const batch = [];

for (let i = 1; i <= 20000; i++) {

    const branchNumber = ((i * 7) % 40) + 1;
    const branchCode = "BR-" + String(branchNumber).padStart(3, "0");

    const amount = Number(
        (((i * 37) % 24000) + 150 + (i % 100) / 100).toFixed(2)
    );

    batch.push({
        txnId: "TXN-" + String(i).padStart(7, "0"),
        branchCode: branchCode,
        accountId: "ACC-" + String(((i * 13) % 9000) + 1).padStart(5, "0"),
        txnType: txnTypes[i % txnTypes.length],
        channel: channels[Math.floor(i / 4) % channels.length],
        status: txnStatuses[i % txnStatuses.length],
        amount: amount,
        currency: "ZAR",
        transactionDate: new Date(
            Date.UTC(2025, i % 12, (i % 27) + 1, i % 24, i % 60, 0)
        ),
        tellerId: "TLR-" + String((i % 150) + 1).padStart(3, "0")
    });

    if (batch.length === 1000) {
        bdb.transactions.insertMany(batch, { ordered: true });
        batch.length = 0;
    }
}

if (batch.length > 0) {
    bdb.transactions.insertMany(batch, { ordered: true });
}

print("Inserted transactions: " + bdb.transactions.countDocuments());

print("Creating audit event...");

bdb.audit_events.insertOne({
    module: "bootstrap",
    eventType: "seed-created",
    operator: "cloudlabs-cse",
    note: "Initial branchops dataset created with 40 branches and 20000 transactions.",
    createdAt: new Date()
});

print("Creating seed indexes...");

/*
 * IMPORTANT: Do not create any index that supports the
 * branch-performance dashboard query. The Module 3 baseline
 * must be a COLLSCAN so the candidate can diagnose it and
 * design the ESR compound index themselves.
 */

bdb.branches.createIndex({ branchCode: 1 }, { unique: true, name: "ux_branchCode" });
bdb.transactions.createIndex({ txnId: 1 }, { unique: true, name: "ux_txnId" });
bdb.transactions.createIndex({ accountId: 1 }, { name: "ix_txn_accountId" });
bdb.audit_events.createIndex(
    { module: 1, eventType: 1, createdAt: -1 },
    { name: "ix_audit_module_event_created" }
);

print("Seed completed.");

printjson({
    database: dbName,
    branches: bdb.branches.countDocuments(),
    transactions: bdb.transactions.countDocuments(),
    audit_events: bdb.audit_events.countDocuments(),
    transaction_indexes: bdb.transactions.getIndexes().length
});
MONGOSEED

chmod 0644 "$SEED_SCRIPT"

# ------------------------------------------------------------
# Execute seed script
# ------------------------------------------------------------

log "Seeding branchops database"

mongosh \
    --host 127.0.0.1 \
    --port 27017 \
    --quiet \
    --file "$SEED_SCRIPT" | tee "${EVIDENCE_DIR}/bootstrap-seed-output.txt"

# ------------------------------------------------------------
# Verify database contents
# ------------------------------------------------------------

log "Running database verification"

COUNTS_OUTPUT="$(
    mongosh branchops --quiet --eval \
        'print("branches=" + db.branches.countDocuments() + ";transactions=" + db.transactions.countDocuments() + ";audit_events=" + db.audit_events.countDocuments())'
)"

log "Counts: $COUNTS_OUTPUT"

echo "$COUNTS_OUTPUT" | grep -q 'branches=40;transactions=20000' || {
    log "ERROR: Unexpected seed counts: $COUNTS_OUTPUT"
    exit 13
}

# The dashboard query must start life as a collection scan.
BASELINE_STAGE="$(
    mongosh branchops --quiet --eval '
const exp = db.transactions.find({
    branchCode: "BR-014",
    status: "completed",
    amount: { $gte: 5000 }
}).sort({ transactionDate: -1 }).limit(50).explain("executionStats");
print(exp.executionStats.executionStages.stage + "/" + exp.queryPlanner.winningPlan.stage);
'
)"

log "Baseline dashboard query stages: $BASELINE_STAGE"

# ------------------------------------------------------------
# Environment file
# ------------------------------------------------------------

log "Creating environment file"

cat > "${WORK_ROOT}/.env" <<'ENVFILE'
MONGODB_URI=mongodb://127.0.0.1:27017/branchops
MONGODB_HOST=127.0.0.1
MONGODB_PORT=27017
MONGODB_DATABASE=branchops
MONGODB_AUTH_MODE=disabled
LAB_WORKSPACE=/opt/cloudlabs/mongodb-dashboard
ENVFILE
chmod 0644 "${WORK_ROOT}/.env"

# ------------------------------------------------------------
# Helper and reset scripts
# ------------------------------------------------------------

log "Creating helper, incident, and reset scripts"

# Module 3: the exact slow dashboard query, ready to explain.
cat > "${SCRIPTS_DIR}/m3-dashboard-query.js" <<'M3QUERY'
// The branch-performance dashboard "recent high-value completed
// transactions" panel. This is the query you must diagnose and
// optimize in Module 3.
const bdb = db.getSiblingDB("branchops");

const cursor = bdb.transactions.find({
    branchCode: "BR-014",
    status: "completed",
    amount: { $gte: 5000 }
}).sort({ transactionDate: -1 }).limit(50);

printjson(cursor.explain("executionStats"));
M3QUERY
chmod 0644 "${SCRIPTS_DIR}/m3-dashboard-query.js"

# Reset helpers
cat > "${RESET_DIR}/reset-dataset.sh" <<'RESETDATA'
#!/usr/bin/env bash
set -euo pipefail
WORK_ROOT="/opt/cloudlabs/mongodb-dashboard"
sudo systemctl enable mongod >/dev/null
sudo systemctl start mongod
mongosh --quiet "${WORK_ROOT}/data/seed-branchops.js"
echo "branchops dataset reset to initial seed state."
RESETDATA
chmod +x "${RESET_DIR}/reset-dataset.sh"

cat > "${RESET_DIR}/clear-evidence.sh" <<'RESETCLEAN'
#!/usr/bin/env bash
set -euo pipefail
WORK_ROOT="/opt/cloudlabs/mongodb-dashboard"
find "${WORK_ROOT}/evidence" -mindepth 1 -maxdepth 1 -type f ! -name 'bootstrap-seed-output.txt' ! -name 'bootstrap-status.json' -delete
find "${WORK_ROOT}/evidence" -mindepth 1 -maxdepth 1 -type d -exec rm -rf {} +
echo "Evidence folder cleared."
RESETCLEAN
chmod +x "${RESET_DIR}/clear-evidence.sh"

# ------------------------------------------------------------
# Workspace README and shell profile helper
# ------------------------------------------------------------

cat > "${WORK_ROOT}/README.txt" <<'README'
MongoDB — Dashboard Query Performance lab workspace

Primary database: branchops
Collections: branches, transactions, audit_events

Key folders:
- data:     seed files
- scripts:  provided helper scripts and the slow dashboard query
- evidence: learner-created validation evidence (Modules 1, 3, 4)
- reset:    reset helpers

The branch-performance dashboard query starts as a COLLSCAN by
design. Module 3 asks you to diagnose it with explain() and fix
it with an ESR-ordered compound index. Module 4 builds the
dashboard aggregation pipeline and scripts automated proof that
the index is used.

Modules 2, 5, 6, and 7 are scenario-and-knowledge-check modules
with no hands-on evidence files or validations.

Do not store passwords, Atlas API keys, private keys, or full
connection strings in evidence files.
README
chmod 0644 "${WORK_ROOT}/README.txt"

cat > /etc/profile.d/cloudlabs-mongodb-dashboard.sh <<'PROFILE'
export DASH_LAB_HOME=/opt/cloudlabs/mongodb-dashboard
alias dashlab='cd /opt/cloudlabs/mongodb-dashboard'
PROFILE
chmod 0644 /etc/profile.d/cloudlabs-mongodb-dashboard.sh

# ------------------------------------------------------------
# Bootstrap status evidence
# ------------------------------------------------------------

cat > "${EVIDENCE_DIR}/bootstrap-status.json" <<EOF
{
  "status": "completed",
  "database": "branchops",
  "branchesSeeded": 40,
  "transactionsSeeded": 20000,
  "dashboardQueryBaselineStage": "COLLSCAN",
  "authenticationInitialState": "disabled",
  "mongodbVersion": "${MONGO_VERSION}",
  "workspace": "${WORK_ROOT}",
  "createdAtUtc": "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
}
EOF
chmod 0644 "${EVIDENCE_DIR}/bootstrap-status.json"

# ------------------------------------------------------------
# Permissions and lab-user symlink
# ------------------------------------------------------------

if [ -n "$LAB_USER" ] && id "$LAB_USER" >/dev/null 2>&1; then
    chown -R "${LAB_USER}:${LAB_USER}" "$WORK_ROOT"
    ln -sfn "$WORK_ROOT" "/home/${LAB_USER}/mongodb-dashboard"
    chown -h "${LAB_USER}:${LAB_USER}" "/home/${LAB_USER}/mongodb-dashboard" || true
fi

chmod -R u+rwX,g+rwX,o+rX "$WORK_ROOT"
chmod -R a+w "$EVIDENCE_DIR" "$SCRIPTS_DIR"

# ------------------------------------------------------------
# Final MongoDB verification
# ------------------------------------------------------------

if ! systemctl is-active --quiet mongod; then
    log "ERROR: MongoDB service is not active."
    exit 1
fi

if ! mongosh \
    --host 127.0.0.1 \
    --port 27017 \
    --quiet \
    --eval 'db.adminCommand({ ping: 1 })' >/dev/null; then

    log "ERROR: Final MongoDB ping failed."
    exit 1
fi

log "=========================================="
log "MongoDB — Dashboard Query Performance"
log "Bootstrap completed successfully"
log "=========================================="
log "MongoDB version: $MONGO_VERSION"
log "Counts: $COUNTS_OUTPUT"
log "Workspace: $WORK_ROOT"
log "Bootstrap log: $BOOTSTRAP_LOG"

exit 0
