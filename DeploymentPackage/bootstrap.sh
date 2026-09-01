#!/usr/bin/env bash

set -euo pipefail

export DEBIAN_FRONTEND=noninteractive

# ============================================================
# MongoDB Customer Data Fundamentals
# Ubuntu 22.04
# MongoDB 7.0
# ============================================================

# ------------------------------------------------------------
# Paths
# ------------------------------------------------------------

LAB_USER="labuser"

WORK_ROOT="/home/${LAB_USER}/mongodb-customer-data"
BACKUP_ROOT="${WORK_ROOT}/backups"
EVIDENCE_ROOT="${WORK_ROOT}/evidence"

TMP_ROOT="/tmp/cloudlabs-mongodb"
SEED_SCRIPT="${TMP_ROOT}/seed-customer360.js"

LOG_DIR="/var/log/cloudlabs"
BOOTSTRAP_LOG="${LOG_DIR}/mongodb-bootstrap.log"

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
log "MongoDB Customer Data Fundamentals"
log "Bootstrap started"
log "=========================================="

# ------------------------------------------------------------
# Validate lab user
# ------------------------------------------------------------

if ! id "$LAB_USER" >/dev/null 2>&1; then
    log "ERROR: User '$LAB_USER' does not exist."
    exit 1
fi

LAB_HOME="$(getent passwd "$LAB_USER" | cut -d: -f6)"

if [ -z "$LAB_HOME" ]; then
    log "ERROR: Could not determine home directory for $LAB_USER."
    exit 1
fi

log "Lab user: $LAB_USER"
log "Lab home: $LAB_HOME"

# ------------------------------------------------------------
# Create learner workspace
# ------------------------------------------------------------

log "Creating learner workspace"

mkdir -p "$WORK_ROOT"
mkdir -p "$BACKUP_ROOT"
mkdir -p "$EVIDENCE_ROOT"

chown -R "${LAB_USER}:${LAB_USER}" "$WORK_ROOT"

chmod 755 "$WORK_ROOT"
chmod 755 "$BACKUP_ROOT"
chmod 755 "$EVIDENCE_ROOT"

# ------------------------------------------------------------
# Create temporary bootstrap directory
# ------------------------------------------------------------

log "Preparing temporary bootstrap directory"

rm -rf "$TMP_ROOT"
mkdir -p "$TMP_ROOT"
chmod 700 "$TMP_ROOT"

# ------------------------------------------------------------
# Install prerequisites
# ------------------------------------------------------------

log "Installing prerequisite packages"

# Fix for Ubuntu command-not-found database update issue
# Remove the problematic post-invoke hook temporarily
rm -f /etc/apt/apt.conf.d/50command-not-found

apt-get update -y

apt-get install -y \
    ca-certificates \
    curl \
    gnupg

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

cat > /etc/apt/sources.list.d/mongodb-org-7.0.list <<'EOF'
deb [ arch=amd64,arm64 signed-by=/usr/share/keyrings/mongodb-server-7.0.gpg ] https://repo.mongodb.org/apt/ubuntu jammy/mongodb-org/7.0 multiverse
EOF

apt-get update -y

# ------------------------------------------------------------
# Install MongoDB
# ------------------------------------------------------------

log "Installing MongoDB"

apt-get install -y mongodb-org

# ------------------------------------------------------------
# Configure MongoDB
# ------------------------------------------------------------

log "Configuring MongoDB"

MONGOD_CONF="/etc/mongod.conf"

if [ ! -f "$MONGOD_CONF" ]; then
    log "ERROR: $MONGOD_CONF was not created."
    exit 1
fi

# Ensure MongoDB listens only on localhost.
# This is intentional for this single-VM assessment environment.

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

    journalctl \
        -u mongod \
        --no-pager \
        -n 100 || true

    exit 1
fi

log "MongoDB is ready"

# ------------------------------------------------------------
# Verify MongoDB version
# ------------------------------------------------------------

MONGO_VERSION="$(
    mongosh \
        --host 127.0.0.1 \
        --port 27017 \
        --quiet \
        --eval 'db.version()'
)"

log "MongoDB version: $MONGO_VERSION"

# ------------------------------------------------------------
# Create temporary seed script
# ------------------------------------------------------------

log "Creating customer360 seed script"

cat > "$SEED_SCRIPT" <<'EOF'
const customer360 = db.getSiblingDB("customer360");

print("Using database: " + customer360.getName());

print("Dropping existing collections...");

customer360.customers.drop();
customer360.orders.drop();
customer360.audit_events.drop();

const firstNames = [
    "Jordan",
    "Taylor",
    "Morgan",
    "Riley",
    "Casey",
    "Jamie",
    "Drew",
    "Quinn",
    "Skyler",
    "Avery"
];

const lastNames = [
    "Diaz",
    "Harris",
    "Khan",
    "Chen",
    "Garcia",
    "Jones",
    "Baker",
    "Evans",
    "Ivanov",
    "Adams"
];

const regions = [
    "South",
    "East",
    "West",
    "Central",
    "North"
];

const loyaltyTiers = [
    "Bronze",
    "Silver",
    "Gold",
    "Platinum"
];

const channels = [
    "email",
    "sms",
    "phone",
    "chat"
];

const cities = [
    "Austin",
    "Boston",
    "Denver",
    "Phoenix",
    "Seattle"
];

const statuses = [
    "active",
    "active",
    "active",
    "active",
    "inactive"
];

const customers = [];

print("Generating 1000 customers...");

for (let i = 1; i <= 1000; i++) {

    const padded = String(i).padStart(4, "0");

    customers.push({
        customerId: `CUST-${padded}`,

        firstName:
            firstNames[(i - 1) % firstNames.length],

        lastName:
            lastNames[(i - 1) % lastNames.length],

        email:
            `customer${padded}@contoso-retail.example`,

        phone:
            `+1-555-${String(i).padStart(6, "0")}`,

        region:
            regions[(i - 1) % regions.length],

        loyaltyTier:
            loyaltyTiers[(i - 1) % loyaltyTiers.length],

        status:
            statuses[(i - 1) % statuses.length],

        createdAt:
            new Date(
                Date.UTC(
                    2023,
                    (i - 1) % 12,
                    ((i - 1) % 27) + 1,
                    9,
                    0,
                    0
                )
            ),

        updatedAt:
            new Date(
                Date.UTC(
                    2023,
                    (i - 1) % 12,
                    ((i - 1) % 27) + 1,
                    9,
                    0,
                    0
                )
            ),

        consent: {
            marketing: i % 3 !== 0,
            supportContact: i % 5 !== 0
        },

        profile: {
            preferredChannel:
                channels[(i - 1) % channels.length],

            lifetimeValueBand:
                i % 3 === 0
                    ? "low"
                    : i % 3 === 1
                        ? "medium"
                        : "high"
        },

        address: {
            city:
                cities[(i - 1) % cities.length],

            country: "US"
        }
    });
}

print("Inserting customers...");

const customerResult =
    customer360.customers.insertMany(customers);

print(
    "Inserted customers: " +
    customerResult.insertedIds.length
);

const orders = [];

print("Generating 5000 orders...");

for (let i = 1; i <= 5000; i++) {

    const customerNumber =
        ((i - 1) % 1000) + 1;

    const customerId =
        `CUST-${String(customerNumber).padStart(4, "0")}`;

    orders.push({

        orderId:
            `ORD-${String(i).padStart(6, "0")}`,

        customerId:
            customerId,

        orderDate:
            new Date(
                Date.UTC(
                    2024,
                    (i - 1) % 12,
                    ((i - 1) % 27) + 1
                )
            ),

        status:
            i % 5 === 0
                ? "cancelled"
                : i % 4 === 0
                    ? "shipped"
                    : "completed",

        amount:
            Number(((i % 250) + 25.50).toFixed(2)),

        channel:
            i % 4 === 0
                ? "web"
                : i % 4 === 1
                    ? "store"
                    : i % 4 === 2
                        ? "mobile"
                        : "partner"
    });
}

print("Inserting orders...");

const orderResult =
    customer360.orders.insertMany(orders);

print(
    "Inserted orders: " +
    orderResult.insertedIds.length
);

print("Creating audit event...");

customer360.audit_events.insertOne({

    eventType: "bootstrap",

    source: "cloudlabs",

    timestamp: new Date(),

    description:
        "customer360 database initialized"
});

print("Creating indexes...");

customer360.customers.createIndex(
    { customerId: 1 },
    { unique: true }
);

customer360.customers.createIndex(
    { email: 1 }
);

customer360.customers.createIndex(
    { region: 1, loyaltyTier: 1 }
);

customer360.orders.createIndex(
    { orderId: 1 },
    { unique: true }
);

customer360.orders.createIndex(
    { customerId: 1 }
);

customer360.orders.createIndex(
    { orderDate: 1 }
);

print("Seed completed.");

printjson({
    database: "customer360",

    customers:
        customer360.customers.countDocuments(),

    orders:
        customer360.orders.countDocuments(),

    audit_events:
        customer360.audit_events.countDocuments(),

    customer_indexes:
        customer360.customers.getIndexes().length,

    order_indexes:
        customer360.orders.getIndexes().length
});
EOF

chmod 600 "$SEED_SCRIPT"

# ------------------------------------------------------------
# Execute seed script
# ------------------------------------------------------------

log "Seeding customer360 database"

mongosh \
    --host 127.0.0.1 \
    --port 27017 \
    --quiet \
    --file "$SEED_SCRIPT"

# ------------------------------------------------------------
# Verify database contents
# ------------------------------------------------------------

log "Running database verification"

CUSTOMER_COUNT="$(
    mongosh \
        --host 127.0.0.1 \
        --port 27017 \
        --quiet \
        --eval '
            const customer360 =
                db.getSiblingDB("customer360");

            print(
                customer360.customers.countDocuments()
            );
        '
)"

ORDER_COUNT="$(
    mongosh \
        --host 127.0.0.1 \
        --port 27017 \
        --quiet \
        --eval '
            const customer360 =
                db.getSiblingDB("customer360");

            print(
                customer360.orders.countDocuments()
            );
        '
)"

AUDIT_COUNT="$(
    mongosh \
        --host 127.0.0.1 \
        --port 27017 \
        --quiet \
        --eval '
            const customer360 =
                db.getSiblingDB("customer360");

            print(
                customer360.audit_events.countDocuments()
            );
        '
)"

log "customers=$CUSTOMER_COUNT"
log "orders=$ORDER_COUNT"
log "audit_events=$AUDIT_COUNT"

# ------------------------------------------------------------
# Validate expected data
# ------------------------------------------------------------

if [ "$CUSTOMER_COUNT" -ne 1000 ]; then
    log "ERROR: Expected 1000 customers, found $CUSTOMER_COUNT"
    exit 1
fi

if [ "$ORDER_COUNT" -ne 5000 ]; then
    log "ERROR: Expected 5000 orders, found $ORDER_COUNT"
    exit 1
fi

if [ "$AUDIT_COUNT" -lt 1 ]; then
    log "ERROR: Expected at least 1 audit event, found $AUDIT_COUNT"
    exit 1
fi

log "Database validation successful"

# ------------------------------------------------------------
# Create a small initial evidence file
# ------------------------------------------------------------

log "Creating initial evidence"

cat > "${EVIDENCE_ROOT}/database-initialization.txt" <<EOF
MongoDB Customer Data Fundamentals
==================================

MongoDB Version:
${MONGO_VERSION}

Database:
customer360

Collections:
customers
orders
audit_events

Initial document counts:
customers=${CUSTOMER_COUNT}
orders=${ORDER_COUNT}
audit_events=${AUDIT_COUNT}

MongoDB Service:
$(systemctl is-active mongod)

Bootstrap completed:
$(date -u '+%Y-%m-%dT%H:%M:%SZ')
EOF

chown "${LAB_USER}:${LAB_USER}" \
    "${EVIDENCE_ROOT}/database-initialization.txt"

chmod 644 \
    "${EVIDENCE_ROOT}/database-initialization.txt"

# ------------------------------------------------------------
# Clean temporary files
# ------------------------------------------------------------

log "Cleaning temporary bootstrap files"

rm -rf "$TMP_ROOT"

# ------------------------------------------------------------
# Final permissions
# ------------------------------------------------------------

chown -R "${LAB_USER}:${LAB_USER}" "$WORK_ROOT"

chmod 755 "$WORK_ROOT"
chmod 755 "$BACKUP_ROOT"
chmod 755 "$EVIDENCE_ROOT"

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

# ------------------------------------------------------------
# Final output
# ------------------------------------------------------------

log "=========================================="
log "MongoDB Customer Data Fundamentals"
log "Bootstrap completed successfully"
log "=========================================="

log "MongoDB status:"
log "active"

log "MongoDB version:"
log "$MONGO_VERSION"

log "Database counts:"
log "customers=$CUSTOMER_COUNT"
log "orders=$ORDER_COUNT"
log "audit_events=$AUDIT_COUNT"

log "Learner workspace:"
log "$WORK_ROOT"

log "Learner directories:"
log "$BACKUP_ROOT"
log "$EVIDENCE_ROOT"

log "Bootstrap log:"
log "$BOOTSTRAP_LOG"

exit 0