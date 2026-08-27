# Instructor Solution Guide — MongoDB Customer Data Fundamentals

## Scope and grading model

This guide covers all seven assessment modules. Grade the demonstrated approach as well as the core end state. Automated validations are deliberately narrower than the rubric.

Use these paths throughout:

```bash
export LAB_ROOT=/opt/cloudlabs/mongodb-customer-data
export SCRIPT_DIR=$LAB_ROOT/scripts
export BACKUP_DIR=$LAB_ROOT/backups
export EVIDENCE_DIR=$LAB_ROOT/evidence
sudo mkdir -p "$SCRIPT_DIR" "$BACKUP_DIR" "$EVIDENCE_DIR"
```

Expected initial state is approximately 1,000 customers and 5,000 orders in `customer360`; do not require exactly 1,000 customers after Module 1. Modules 1–4 start without MongoDB authorization. Module 5 enables authorization. Module 6 occurs after that transition, so authenticated data queries may be required even though `ping` and Linux service checks remain useful.

## Azure platform checks

The lab is one Ubuntu 22.04 Azure VM initialized by the Azure Custom Script Extension. The portal path is **Resource groups → lab resource group → Virtual machine → Overview/Connect**. For a Linux VM, confirm power state before investigating guest services. Azure VM Run Command can execute a shell script through the VM agent and is useful when SSH is unavailable; it is not a substitute for fixing guest networking.

Instructor Azure CLI checks:

```bash
az account set --subscription "$SUBSCRIPTION_ID"
RG="rg-mongodb-customer-data-$DID"
az group show -n "$RG" --query '{name:name,location:location,provisioningState:properties.provisioningState}' -o table
az vm list -g "$RG" -d --query '[].{Name:name,Location:location,PowerState:powerState,PublicIP:publicIps}' -o table
VM=$(az vm list -g "$RG" --query '[0].name' -o tsv)
az vm get-instance-view -g "$RG" -n "$VM" --query 'instanceView.statuses[].displayStatus' -o tsv
az vm extension list -g "$RG" --vm-name "$VM" --query '[].{Name:name,Publisher:publisher,Type:type,State:provisioningState}' -o table
az vm run-command invoke -g "$RG" -n "$VM" --command-id RunShellScript \
  --scripts 'systemctl is-active mongod; systemctl is-enabled mongod; mongosh --quiet --eval '\''db.adminCommand({ping:1})'\'''
```

Equivalent Azure PowerShell checks:

```powershell
Set-AzContext -Subscription $env:SUBSCRIPTION_ID
$rg = "rg-mongodb-customer-data-$env:DID"
$vm = Get-AzVM -ResourceGroupName $rg | Where-Object {$_.StorageProfile.OSDisk.OSType -eq 'Linux'} | Select-Object -First 1
Get-AzVM -ResourceGroupName $rg -Name $vm.Name -Status
Get-AzVMExtension -ResourceGroupName $rg -VMName $vm.Name
Invoke-AzVMRunCommand -ResourceGroupName $rg -VMName $vm.Name `
  -CommandId 'RunShellScript' `
  -ScriptString 'systemctl is-active mongod; systemctl is-enabled mongod'
```

Microsoft Learn references for instructor fact-checking:

- Linux VM SSH/Connect: <https://learn.microsoft.com/azure/virtual-machines/linux-vm-connect>
- VM instance view and power states: <https://learn.microsoft.com/azure/virtual-machines/states-billing>
- Azure CLI Run Command: <https://learn.microsoft.com/azure/virtual-machines/linux/run-command-managed>
- PowerShell `Invoke-AzVMRunCommand`: <https://learn.microsoft.com/powershell/module/az.compute/invoke-azvmruncommand>
- Linux Custom Script Extension: <https://learn.microsoft.com/azure/virtual-machines/extensions/custom-script-linux>

Azure troubleshooting cautions:

- Resource group location and VM location are separate properties; do not infer the VM region from the resource group alone.
- The Custom Script Extension does not require a system-assigned identity when artifacts are anonymously readable. Private artifact access requires a supported authenticated design and correct identity/RBAC configuration.
- Azure RBAC assignments can take time to propagate. Retry after confirming scope and principal rather than granting broad roles.
- A stopped guest `mongod` service is not an Azure VM power-state failure. Start the VM first only if its Azure power state is deallocated/stopped.
- Do not open TCP 27017 to the Internet. MongoDB is intended to remain locally bound in Modules 1–6.
- Soft deletion can block immediate recreation of resource types that support it, but it is not relevant to restarting this VM or `mongod`. Do not purge unrelated resources.
- Storage SKU throttling can present as guest I/O latency. Check Azure disk metrics only after service, logs, free space, and guest I/O checks; changing a disk SKU is outside this assessment.

---

## Module 1 — Manage customer records

### Reference approach and commands

Inspect the data before changing it:

```bash
systemctl is-active mongod
mongosh customer360 --quiet --eval '
printjson({collections: db.getCollectionNames().sort()});
printjson({customers: db.customers.countDocuments(), orders: db.orders.countDocuments(), auditEvents: db.audit_events.countDocuments()});
printjson(db.customers.findOne());
printjson(db.orders.findOne());'
```

Insert the known assessment customer idempotently:

```bash
mongosh customer360 --quiet <<'EOF'
db.customers.updateOne(
  { customerId: "CUST-ASSESS-M1" },
  { $setOnInsert: {
      customerId: "CUST-ASSESS-M1",
      firstName: "Assessment",
      lastName: "Operator",
      email: "candidate.m1@contoso-retail.example",
      region: "West",
      loyaltyTier: "Silver",
      status: "active",
      consent: { marketing: true, supportContact: true },
      createdAt: new Date()
  }},
  { upsert: true }
);
EOF
```

Apply collection validation. `validationLevel: "moderate"` enforces inserts and updates of valid documents while reducing the risk that an unrelated legacy document blocks this exercise. `validationAction: "error"` rejects violations.

```bash
mongosh customer360 --quiet <<'EOF'
printjson(db.runCommand({
  collMod: "customers",
  validator: { $jsonSchema: {
    bsonType: "object",
    required: ["customerId", "email", "region", "loyaltyTier", "status", "consent"],
    properties: {
      customerId: { bsonType: "string" },
      email: { bsonType: "string" },
      region: { bsonType: "string" },
      loyaltyTier: { bsonType: "string" },
      status: { enum: ["active", "inactive"] },
      consent: {
        bsonType: "object",
        required: ["marketing", "supportContact"],
        properties: {
          marketing: { bsonType: "bool" },
          supportContact: { bsonType: "bool" }
        }
      }
    }
  }},
  validationLevel: "moderate",
  validationAction: "error"
}));
EOF
```

Update the customer and write an idempotent audit record:

```bash
mongosh customer360 --quiet <<'EOF'
printjson(db.customers.updateOne(
  { customerId: "CUST-ASSESS-M1" },
  { $set: { loyaltyTier: "Gold", status: "inactive", updatedAt: new Date() } }
));
printjson(db.audit_events.updateOne(
  { module: "M1", customerId: "CUST-ASSESS-M1", eventType: "customer-record-management" },
  { $set: {
      operator: "candidate",
      note: "Inserted customer, enabled validation, and changed tier/status.",
      createdAt: new Date()
  }},
  { upsert: true }
));
EOF
```

A valid negative test should fail with document validation error code 121:

```bash
mongosh customer360 --quiet --eval '
db.customers.insertOne({customerId:"M1-BAD-TEMP",email:"bad@example",region:"West",loyaltyTier:"Silver",status:"pending",consent:{marketing:"true",supportContact:true}})'
```

### Expected verification

```bash
mongosh customer360 --quiet <<'EOF'
printjson(db.customers.findOne({customerId:"CUST-ASSESS-M1"}));
print("candidateCount=" + db.customers.countDocuments({customerId:"CUST-ASSESS-M1"}));
printjson(db.getCollectionInfos({name:"customers"})[0].options);
printjson(db.audit_events.findOne({module:"M1",customerId:"CUST-ASSESS-M1"}));
EOF
```

Expected: count `1`, tier `Gold`, status `inactive`, Boolean consent fields, collection `validator` present, and one matching audit event.

### Rubric

- **Full credit:** inspects database/collections/counts; creates the exact customer once; implements required validator with rejecting action; negative test is rejected; updates tier/status; records required audit event.
- **Partial credit:** customer and audit event exist but validator is incomplete, field types are wrong, duplicate records exist, or no negative test is demonstrated.
- **No core credit:** wrong database, missing known customer, no validator, or destructive changes to seed data.

### Common mistakes

- Strings `"true"`/`"false"` instead of BSON Booleans.
- Using `profile.firstName` while the required assessment fields are top-level, or omitting `supportContact`.
- Setting `validationAction: "warn"`; malformed writes then succeed.
- Running the insert twice without an upsert and producing duplicates.
- Making the validator incompatible with seeded records. Inspect samples first.

### Reset/cleanup

Prefer the packaged seed reset helper after reviewing it:

```bash
ls -la "$LAB_ROOT/reset"
sudo find "$LAB_ROOT/reset" -maxdepth 1 -type f -printf '%f\n'
```

For Module 1-only cleanup:

```bash
mongosh customer360 --quiet <<'EOF'
db.customers.deleteMany({customerId:{$in:["CUST-ASSESS-M1","M1-BAD-TEMP"]}});
db.audit_events.deleteMany({module:"M1"});
EOF
```

Do not remove the validator if Module 1 will be revalidated. To remove it for a clean reseed: `db.runCommand({collMod:"customers",validator:{}})`.

---

## Module 2 — Protect the dataset

### Reference approach and commands

Capture a baseline:

```bash
mongosh customer360 --quiet --eval '
printjson({capturedAt:new Date(),customers:db.customers.countDocuments(),orders:db.orders.countDocuments(),audit_events:db.audit_events.countDocuments()})' \
| sudo tee "$EVIDENCE_DIR/m2-pre-backup-counts.json"
```

Create the reusable script:

```bash
sudo tee "$SCRIPT_DIR/m2-backup-customer360.sh" >/dev/null <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
ROOT=/opt/cloudlabs/mongodb-customer-data/backups
DEST="$ROOT/customer360-$(date -u +%Y%m%dT%H%M%SZ)"
mkdir -p "$DEST"
mongodump --db customer360 --out "$DEST"
test -s "$DEST/customer360/customers.bson"
test -s "$DEST/customer360/orders.bson"
echo "Backup completed: $DEST"
EOF
sudo chmod 0755 "$SCRIPT_DIR/m2-backup-customer360.sh"
"$SCRIPT_DIR/m2-backup-customer360.sh" | sudo tee "$EVIDENCE_DIR/m2-backup-run.txt"
```

After Module 5, append authenticated options or use a URI held only in an environment variable; never place credentials in the script. This module normally precedes authentication.

Simulate and prove controlled loss:

```bash
mongosh customer360 --quiet --eval '
const ids=db.customers.find({status:"inactive"},{_id:1}).limit(10).toArray().map(x=>x._id);
const r=db.customers.deleteMany({_id:{$in:ids}});
printjson({deletedIds:ids,deletedCount:r.deletedCount});' \
| sudo tee "$EVIDENCE_DIR/m2-simulated-loss.json"
```

Restore the latest backup:

```bash
LATEST_BACKUP=$(find "$BACKUP_DIR" -mindepth 1 -maxdepth 1 -type d -name 'customer360-*' -printf '%T@ %p\n' | sort -nr | head -1 | cut -d' ' -f2-)
test -n "$LATEST_BACKUP"
mongorestore --drop --db customer360 "$LATEST_BACKUP/customer360"
mongosh customer360 --quiet --eval '
printjson({restoredAt:new Date(),customers:db.customers.countDocuments(),orders:db.orders.countDocuments(),candidate:db.customers.findOne({customerId:"CUST-ASSESS-M1"})});' \
| sudo tee "$EVIDENCE_DIR/m2-restored-counts.json"
sudo tee "$EVIDENCE_DIR/m2-recovery-marker.txt" >/dev/null <<EOF
Module 2 recovery completed
Backup used: $LATEST_BACKUP
Restore used --drop and post-restore counts were captured.
EOF
```

### Expected verification

```bash
find "$BACKUP_DIR" -type f \( -name 'customers.bson' -o -name 'orders.bson' \) -size +0c -print
cat "$EVIDENCE_DIR/m2-pre-backup-counts.json"
cat "$EVIDENCE_DIR/m2-restored-counts.json"
test -s "$EVIDENCE_DIR/m2-recovery-marker.txt" && echo PASS
```

Restored customer and order counts must equal the pre-backup counts. The known M1 customer should exist if it was present when the backup was made.

### Rubric

- **Full credit:** executable reusable timestamped backup script; nonempty BSON artifacts; controlled loss shown; correct backup selected; restore completed; before/after counts agree; marker exists.
- **Partial credit:** usable dump and restored data exist, but script is not reusable, timestamps/evidence are absent, or verification is incomplete.
- **No core credit:** no backup artifact, wrong database restored, or final dataset remains damaged.

### Common mistakes

- Passing the timestamp parent directory rather than its `customer360` child to `mongorestore --db`.
- Omitting `--drop`, which can leave records introduced after backup and make counts differ.
- Selecting a stale backup by lexicographic assumptions; verify timestamp and contents.
- Backing up after the deletion.
- Running Module 2 after authorization without authenticated `mongodump`/`mongorestore` options.

### Reset/cleanup

Do not remove the successful artifact before validation. For a rerun:

```bash
sudo rm -rf "$BACKUP_DIR"/customer360-*
sudo rm -f "$EVIDENCE_DIR"/m2-*
# Then use the packaged seed reset helper if counts are not trustworthy.
ls -la "$LAB_ROOT/reset"
```

---

## Module 3 — Optimize a slow query

### Reference approach and commands

Remove only the target index when demonstrating a true baseline:

```bash
mongosh customer360 --quiet --eval '
if (db.orders.getIndexes().some(i=>i.name==="region_orderDate_status_perf_idx")) db.orders.dropIndex("region_orderDate_status_perf_idx")'
```

Capture the baseline and optimized plan to the exact evidence path:

```bash
EVIDENCE="$EVIDENCE_DIR/module3-explain-evidence.txt"
sudo touch "$EVIDENCE" && sudo chown "$USER":"$USER" "$EVIDENCE"
: > "$EVIDENCE"
mongosh customer360 --quiet <<'EOF' | tee -a "$EVIDENCE"
print("BEFORE explain baseline");
const e=db.orders.find({region:"West",orderDate:{$gte:ISODate("2024-01-01T00:00:00Z")},status:"SHIPPED"}).sort({orderDate:-1}).explain("executionStats");
printjson({winningPlan:e.queryPlanner.winningPlan,nReturned:e.executionStats.nReturned,totalKeysExamined:e.executionStats.totalKeysExamined,totalDocsExamined:e.executionStats.totalDocsExamined,executionTimeMillis:e.executionStats.executionTimeMillis});
EOF

mongosh customer360 --quiet --eval 'db.orders.createIndex({region:1,orderDate:-1,status:1},{name:"region_orderDate_status_perf_idx"})'

mongosh customer360 --quiet <<'EOF' | tee -a "$EVIDENCE"
print("AFTER explain optimized");
const e=db.orders.find({region:"West",orderDate:{$gte:ISODate("2024-01-01T00:00:00Z")},status:"SHIPPED"}).sort({orderDate:-1}).explain("executionStats");
printjson({winningPlan:e.queryPlanner.winningPlan,nReturned:e.executionStats.nReturned,totalKeysExamined:e.executionStats.totalKeysExamined,totalDocsExamined:e.executionStats.totalDocsExamined,executionTimeMillis:e.executionStats.executionTimeMillis});
print("JUSTIFICATION: compound index supports region equality, descending orderDate range/sort, and status predicate.");
EOF
```

### Expected verification

```bash
mongosh customer360 --quiet --eval '
printjson(db.orders.getIndexes().filter(i=>tojson(i.key)===tojson({region:1,orderDate:-1,status:1})))'
grep -Ei 'BEFORE|AFTER|explain|totalDocsExamined|IXSCAN' "$EVIDENCE"
```

The automated validator requires the exact ordered key pattern `{ region: 1, orderDate: -1, status: 1 }` and a nonempty file containing `before`, `after`, and `explain`. Typically the baseline has `COLLSCAN` and the optimized plan includes `IXSCAN`; execution time may remain near zero on this small dataset and is not a reliable grading criterion.

### Rubric

- **Full credit:** same predicate/sort before and after; exact compound index; execution statistics preserved; plan/scans interpreted correctly; concise justification.
- **Partial credit:** correct index exists but evidence is incomplete, query changed between tests, or explanation relies only on elapsed time.
- **No core credit:** wrong field order/direction, no index, or fabricated evidence.

### Common mistakes

- Using `orderStatus` instead of seeded `status`, or a date stored as a string rather than BSON Date.
- Creating the index before the baseline.
- Comparing different query shapes.
- Expecting `totalDocsExamined` to be zero; this is not a covered query because returned document fields still require fetches.
- Assuming the named index alone is enough; validator checks key order and direction.

### Reset/cleanup

```bash
mongosh customer360 --quiet --eval 'db.orders.dropIndex("region_orderDate_status_perf_idx")'
sudo rm -f "$EVIDENCE"
```

Keep both until grading completes.

---

## Module 4 — Analyze business metrics

### Reference approach and commands

First inspect real field names and status values:

```bash
mongosh customer360 --quiet --eval 'printjson(db.orders.findOne()); printjson(db.orders.distinct("status")); printjson(db.orders.distinct("orderStatus"))'
```

The candidate script must use all four required stages. If the seeded data uses `SHIPPED` rather than a completed variant, add it to the match list so output is nonempty:

```bash
sudo tee "$SCRIPT_DIR/analytics-report.mongodb.js" >/dev/null <<'EOF'
const d=db.getSiblingDB("customer360");
print("Customer360 operational metric: completed/shipped revenue by product category");
const results=d.orders.aggregate([
  {$match: {$or: [
    {status: {$in:["SHIPPED","Completed","completed","COMPLETE"]}},
    {orderStatus: {$in:["SHIPPED","Completed","completed","COMPLETE"]}}
  ]}},
  {$group: {
    _id: {$ifNull:["$productCategory","$category"]},
    orderCount: {$sum:1},
    totalRevenue: {$sum:{$ifNull:["$totalAmount",{$ifNull:["$orderTotal","$total"]}]}},
    averageOrderValue: {$avg:{$ifNull:["$totalAmount",{$ifNull:["$orderTotal","$total"]}]}}
  }},
  {$project: {_id:0,productCategory:{$ifNull:["$_id","Uncategorized"]},orderCount:1,totalRevenue:{$round:["$totalRevenue",2]},averageOrderValue:{$round:["$averageOrderValue",2]}}},
  {$sort: {totalRevenue:-1,orderCount:-1}}
]).toArray();
printjson(results);
EOF
mongosh --quiet "$SCRIPT_DIR/analytics-report.mongodb.js" | sudo tee "$EVIDENCE_DIR/m4-analytics-output.txt"
```

### Expected verification

```bash
grep -nE '\$match|\$group|\$project|\$sort' "$SCRIPT_DIR/analytics-report.mongodb.js"
test -s "$EVIDENCE_DIR/m4-analytics-output.txt" && head -40 "$EVIDENCE_DIR/m4-analytics-output.txt"
```

Expected output is an array with `productCategory`, `orderCount`, `totalRevenue`, and `averageOrderValue`, sorted by descending revenue. Exact values depend on seed data and prior restore state.

### Rubric

- **Full credit:** reusable exact-path script; all required stages perform meaningful work; `$match` occurs early; execution succeeds with readable metric output and evidence.
- **Partial credit:** all stages exist but output is empty due to incorrect values/fields, evidence is absent, or aggregation is only interactive.
- **No core credit:** script missing or required stages absent.

### Common mistakes

- Shell expanding `$match` in an unquoted heredoc. Use `<<'EOF'`.
- Matching status values with incorrect case.
- Grouping on nonexistent fields, producing only `Uncategorized` and zero/null revenue.
- Sorting before grouping, which does not rank the final aggregates.

### Reset/cleanup

```bash
sudo rm -f "$SCRIPT_DIR/analytics-report.mongodb.js" "$EVIDENCE_DIR/m4-analytics-output.txt"
```

Do this only after validation.

---

## Module 5 — Secure MongoDB access

### Reference approach and commands

Keep generated passwords only in the current process environment. Do not echo them, put them in command history as literals, or write them to evidence.

```bash
export C360_ADMIN_PASSWORD="$(openssl rand -base64 24)"
export C360_REPORT_PASSWORD="$(openssl rand -base64 24)"
mongosh admin --quiet --eval '
db.createUser({user:"c360Admin",pwd:process.env.C360_ADMIN_PASSWORD,roles:[{role:"root",db:"admin"}]})'
```

Back up and update `/etc/mongod.conf`:

```bash
sudo cp -a /etc/mongod.conf /etc/mongod.conf.m5-preauth
sudo python3 - <<'PY'
from pathlib import Path
p=Path('/etc/mongod.conf')
s=p.read_text()
if 'security:' not in s:
    s += '\nsecurity:\n  authorization: enabled\n'
elif 'authorization:' not in s:
    s=s.replace('security:', 'security:\n  authorization: enabled', 1)
else:
    import re
    s=re.sub(r'(?m)^\s*authorization:\s*\S+\s*$', '  authorization: enabled', s, count=1)
p.write_text(s)
PY
sudo systemctl restart mongod
systemctl is-active mongod
```

Authenticate to the `admin` authentication database and create the database-scoped reader:

```bash
mongosh admin --quiet -u c360Admin --password "$C360_ADMIN_PASSWORD" --authenticationDatabase admin --eval '
db.getSiblingDB("customer360").createUser({user:"c360Reporter",pwd:process.env.C360_REPORT_PASSWORD,roles:[{role:"read",db:"customer360"}]})'
```

Test authorization:

```bash
mongosh customer360 --quiet -u c360Reporter --password "$C360_REPORT_PASSWORD" --authenticationDatabase customer360 \
  --eval 'print(db.customers.countDocuments())'

set +e
mongosh customer360 --quiet -u c360Reporter --password "$C360_REPORT_PASSWORD" --authenticationDatabase customer360 \
  --eval 'db.orders.insertOne({securityTest:true,createdAt:new Date()})' >/tmp/m5-write.out 2>&1
WRITE_RC=$?
mongosh customer360 --quiet -u c360Reporter --password "$C360_REPORT_PASSWORD" --authenticationDatabase customer360 \
  --eval 'db.getSiblingDB("admin").runCommand({usersInfo:1})' >/tmp/m5-admin.out 2>&1
ADMIN_RC=$?
set -e
test "$WRITE_RC" -ne 0 && test "$ADMIN_RC" -ne 0 && echo 'Denied tests behaved correctly'
```

Create sanitized evidence:

```bash
sudo tee "$EVIDENCE_DIR/m5-security-evidence.txt" >/dev/null <<EOF
Module 5 security evidence
authorization=enabled
adminUser=c360Admin
reportingUser=c360Reporter
reportingRole=read@customer360
allowedReadExitCode=0
deniedWriteExitCode=$WRITE_RC
deniedAdminExitCode=$ADMIN_RC
Secrets stored: No
EOF
rm -f /tmp/m5-write.out /tmp/m5-admin.out
```

### Expected verification

```bash
sudo grep -A2 '^security:' /etc/mongod.conf
mongosh admin --quiet -u c360Admin --password "$C360_ADMIN_PASSWORD" --authenticationDatabase admin --eval '
printjson(db.getUser("c360Admin")); printjson(db.getSiblingDB("customer360").getUser("c360Reporter"));'
grep -Ei 'password|mongodb(\+srv)?://' "$EVIDENCE_DIR/m5-security-evidence.txt" || echo 'No obvious secrets/URIs found'
```

Expected: authorization enabled; admin user in `admin`; reporter in `customer360` with only `read@customer360`; read succeeds; write/admin operations fail as unauthorized; evidence contains no secret values.

### Rubric

- **Full credit:** admin exists before authorization transition; authorization enabled; least-privilege reporter has only `read`; allowed and denied tests proven; sanitized evidence exists.
- **Partial credit:** authentication works but reporter is overprivileged, denial evidence is weak, or configuration backup is missing.
- **No core credit:** authorization disabled, no usable admin, or secrets are written into evidence.

### Common mistakes

- Creating the first admin after enabling authorization and becoming locked out.
- Authenticating `c360Admin` against `customer360` instead of `admin`, or the reporter against the wrong authentication database.
- Treating expected authorization failures as task failures.
- Assigning `readWrite`, `dbAdmin`, `userAdmin`, or `root` to the reporter.
- Losing the process environment before Module 6. Keep the same instructor-controlled session or use the supplied auth transition/reset helper; never recover by publishing a password.
- Duplicating YAML `security` keys or breaking indentation. Check `journalctl -u mongod` after restart.

### Reset/cleanup and safe recovery

If credentials are known, remove the users before disabling authorization:

```bash
mongosh admin --quiet -u c360Admin --password "$C360_ADMIN_PASSWORD" --authenticationDatabase admin <<'EOF'
db.getSiblingDB("customer360").dropUser("c360Reporter");
db.dropUser("c360Admin");
EOF
sudo cp -a /etc/mongod.conf.m5-preauth /etc/mongod.conf
sudo systemctl restart mongod
```

If credentials were lost, use only the packaged instructor auth reset helper after inspecting it:

```bash
ls -la "$LAB_ROOT/reset"
sudo grep -RIl 'authorization\|mongod.conf' "$LAB_ROOT/reset"
```

Do not improvise by exposing port 27017 or weakening `bindIp`. A reset may invalidate Module 5 grading and must be followed by re-completion.

---

## Module 6 — Troubleshoot and recover `mongod`

### Fault injection for instructor

Inject only the documented fault:

```bash
sudo systemctl disable --now mongod
systemctl is-active mongod || true
systemctl is-enabled mongod || true
```

Expected pre-recovery states are `inactive` and `disabled`; no `mongod` process or TCP 27017 listener should exist.

### Diagnostic approach

The candidate should collect evidence before changing state:

```bash
mongosh --quiet --eval 'db.adminCommand({ping:1})' || true
systemctl status mongod --no-pager || true
systemctl is-active mongod || true
systemctl is-enabled mongod || true
pgrep -a mongod || true
sudo ss --listen --tcp --process --numeric | grep ':27017' || true
sudo journalctl -u mongod --no-pager -n 40
df -h
free -h
```

Interpretation: `inactive` plus `disabled`, no process, and no listener identify a service-state incident. A normal shutdown in the journal and adequate disk/memory argue against corruption or resource exhaustion. Authentication errors would require a running listener and are not the injected root cause.

### Exact service recovery

```bash
sudo systemctl enable mongod
sudo systemctl start mongod
# Equivalent single command: sudo systemctl enable --now mongod
systemctl is-active mongod
systemctl is-enabled mongod
pgrep -a mongod
sudo ss --listen --tcp --process --numeric | grep ':27017'
mongosh --quiet --eval 'db.adminCommand({ping:1})'
```

Expected service outputs are `active` and `enabled`; ping should return `{ ok: 1 }` or equivalent. If Module 5 authorization remains enabled, verify collection access with the retained environment variable:

```bash
mongosh admin --quiet -u c360Admin --password "$C360_ADMIN_PASSWORD" --authenticationDatabase admin --eval '
const d=db.getSiblingDB("customer360"); printjson({customers:d.customers.countDocuments(),orders:d.orders.countDocuments()});'
```

If the candidate no longer has credentials, the service recovery itself is still valid. The instructor should use the packaged auth recovery process rather than changing network exposure or recording credentials.

Create evidence:

```bash
sudo tee "$EVIDENCE_DIR/m6-incident-note.txt" >/dev/null <<'EOF'
Module 6 incident note
Symptom: local MongoDB connection failed.
Diagnosis: mongod was stopped and disabled; no process or TCP 27017 listener existed.
Checks: systemd state, enablement, process, listener, journal, disk, and memory.
Recovery: enabled and started mongod.
Verification: mongod active/enabled, ping succeeded, and customer360 was readable with authorized access where required.
EOF
```

### If recovery does not start the service

Do not delete database files. Diagnose in this order:

```bash
sudo systemctl status mongod --no-pager -l
sudo journalctl -u mongod --since '-10 minutes' --no-pager
sudo mongod --config /etc/mongod.conf --configExpand none --help >/dev/null 2>&1 || true
sudo grep -nE '^(storage:|systemLog:|net:|security:)|dbPath|path:|bindIp|port|authorization' /etc/mongod.conf
df -h / /var/lib/mongodb /var/log/mongodb
sudo ls -ld /var/lib/mongodb /var/log/mongodb
sudo ss -ltnp | grep ':27017' || true
```

Likely post-Module-5 issue: malformed YAML. Compare `/etc/mongod.conf` with `/etc/mongod.conf.m5-preauth`, correct only the security stanza, then `sudo systemctl restart mongod`. Do not run repair, remove lock files, or change ownership unless logs specifically prove that fault.

### Expected verification and validation

```bash
systemctl is-active --quiet mongod && echo active
systemctl is-enabled --quiet mongod && echo enabled
test -s "$EVIDENCE_DIR/m6-incident-note.txt" && echo evidence-present
```

Automated validation is expected to check active/enabled state, a successful local database check, and exact-path incident evidence.

### Rubric

- **Full credit:** diagnoses before remediation using all required evidence classes; correctly distinguishes service state from network/auth/data damage; enables and starts service; verifies process, listener, ping/data; writes accurate note.
- **Partial credit:** service recovered and note exists, but diagnosis lacks logs/resources/port checks or persistence (`enable`) is omitted.
- **No core credit:** service remains inactive/disabled, data files are destructively modified, or evidence is absent.

### Common mistakes

- Running only `start`; service then fails again after reboot because it remains disabled.
- Opening NSG port 27017. The failure is local service state, not inbound Azure networking.
- Confusing authorization errors after Module 5 with the initial connection-refused symptom.
- Running `mongod --repair` without corruption evidence.
- Restarting the Azure VM before gathering guest evidence.

### Reset/cleanup

To re-inject the fault, use `sudo systemctl disable --now mongod`. To unblock any learner, use `sudo systemctl enable --now mongod`. Remove the note only when deliberately resetting grading:

```bash
sudo rm -f "$EVIDENCE_DIR/m6-incident-note.txt"
```

---

## Module 7 — BYO Atlas cloud operations

### Instructor guidance

The Azure deployment does not create, inspect, or validate Atlas resources. The candidate uses an account/project they control, or completes an instructor-approved observation-only path. Do not ask for Atlas usernames, passwords, API keys, private keys, access tokens, screenshots containing credentials, or a completed connection URI.

Candidate workflow:

1. In Atlas, create/select a project and a free or approved low-cost cluster. Do not require paid backup or a paid tier.
2. Under **Database Access**, create/select a lab-safe database user with only the role needed for the synthetic `customer360` data (for example, read/write limited to that database). Project/organization roles are distinct from database user privileges.
3. Under **Network Access**, allow the actual client egress IP or an organization-approved range. Avoid `0.0.0.0/0` unless explicitly approved for a short-lived training environment, then remove it immediately afterward.
4. Use Atlas Data Explorer, Compass, or `mongosh`. If `mongosh` is used, paste an uncredentialed template and enter the password interactively. Do not put a completed URI in shell history, command arguments, or evidence.
5. Insert only synthetic data:

```javascript
use customer360
db.customers.updateOne(
  {customerId:"atlas-lab-001"},
  {$set:{customerId:"atlas-lab-001",profile:{firstName:"Atlas",lastName:"Operator"},region:"North America",loyaltyTier:"Gold",status:"active",consent:{email:true,sms:false},source:"cloud-operations-lab"}},
  {upsert:true}
)
db.customers.findOne({customerId:"atlas-lab-001"})
```

6. Review one security setting, one metric, backup availability/state for the selected tier, and a connection troubleshooting workflow.

Create the exact local evidence file with actual non-secret observations rather than placeholders:

```bash
sudo install -m 600 /dev/null "$EVIDENCE_DIR/atlas-operations-evidence.txt"
sudo tee "$EVIDENCE_DIR/atlas-operations-evidence.txt" >/dev/null <<'EOF'
Atlas Project Name: customer360-lab
Atlas Cluster Name: customer360-atlas-lab
Connection Method Used: Atlas Data Explorer, Compass, or interactive mongosh
Network Access Approach: current client egress IP allowlisted temporarily
Database Access Role Observed: least-privilege readWrite on customer360
Sample Data Action: synthetic atlas-lab-001 customer upserted
Security Setting Reviewed: database user and project access reviewed
Monitoring Metric Reviewed: connections and operations observed
Backup Setting Observed: record enabled, disabled, or unavailable for selected tier
Troubleshooting Note: check cluster state, client IP access list, database user/auth source, and DNS/SRV resolution
Secrets Stored: No
EOF
```

Replace the bracketed cluster name without adding a host, URI, user, or credential. Scan before validation:

```bash
FILE="$EVIDENCE_DIR/atlas-operations-evidence.txt"
test -s "$FILE"
grep -E '^(Atlas Project Name|Atlas Cluster Name|Connection Method Used|Network Access Approach|Backup Setting Observed|Troubleshooting Note|Secrets Stored):' "$FILE"
if grep -Eiq 'mongodb(\+srv)?://|password\s*[=:]|api[_ -]?key\s*[=:]|BEGIN [A-Z ]*PRIVATE KEY|@[^ ]*mongodb\.net' "$FILE"; then
  echo 'FAIL: remove possible secret or full URI material'
else
  echo 'PASS: no obvious secret pattern detected'
fi
```

### Expected verification and validation

Manual grading should confirm the candidate can describe the selected project/cluster, access controls, connection method, synthetic data action, monitoring, backup state, and one troubleshooting sequence. Local automated validation should only check required evidence fields and reject obvious secret patterns; it cannot attest that Atlas work actually occurred.

A good troubleshooting explanation is:

1. Confirm cluster is available.
2. Confirm the connecting client's current public egress IP is covered by the project IP access list.
3. Confirm the database user exists, has the required database role, and uses the correct authentication mechanism/source.
4. Re-copy the connection template for the selected cluster without saving credentials.
5. Check DNS/SRV resolution and outbound connectivity from the chosen client.

### Rubric

- **Full credit:** project/cluster selected; least-privilege database and scoped network access explained; safe connection demonstrated; synthetic data exists; security/metric/backup review completed; useful local evidence contains no secrets.
- **Partial credit:** observation-only completion is instructor-approved or one operational area cannot be changed because of account/tier limitations, but evidence accurately records the limitation and remaining checks.
- **No core credit:** required evidence absent/placeholder-only, real customer data uploaded, or credentials/full URI stored.

### Common mistakes

- Confusing Atlas project membership with database-user authorization.
- Allowlisting the Azure VM public IP while connecting from a laptop, or vice versa. Atlas must see the egress IP of the actual client.
- Assuming backup is available on every free/shared tier. Grade accurate observation, not paid-feature enablement.
- Saving a completed `mongodb+srv://user:password@...` URI in evidence or shell history.
- Copying real customer data into a personal Atlas project.
- Treating the local validator as proof of Atlas configuration.

### Cleanup

In the candidate's Atlas project:

- Delete `atlas-lab-001` or the temporary sample database if no longer needed.
- Remove temporary IP access-list entries, especially any broad range.
- Delete the temporary database user.
- Pause/delete the training cluster if permitted and verify billing implications in the candidate-owned account.
- Do not delete organizational resources or shared projects.

On the lab VM:

```bash
sudo rm -f "$EVIDENCE_DIR/atlas-operations-evidence.txt"
unset C360_ADMIN_PASSWORD C360_REPORT_PASSWORD
history -d "$(history 1 | awk '{print $1}')" 2>/dev/null || true
```

Retain evidence until grading is complete.

---

## Validation expectations summary

| Module | Core validator expectation | Instructor checks beyond automation |
|---|---|---|
| 1 | Reachable database, collections, known customer, validator, audit event | Correct types, final Gold/inactive state, negative test, no duplicates |
| 2 | Backup artifact, restore marker, expected data/counts | Backup preceded loss, correct restore point, repeatable script |
| 3 | Exact compound index and exact evidence file with before/after explain | Same query shape and sound interpretation |
| 4 | Exact script path and literal `$match`, `$group`, `$project`, `$sort` | Successful nonempty and meaningful report |
| 5 | Authorization, users, least-privilege evidence | Reporter only has required role; allowed/denied tests; no secrets |
| 6 | `mongod` active/enabled, database available, incident note | Diagnosis gathered before recovery; no unnecessary repair/network changes |
| 7 | Exact local evidence fields and no obvious secret patterns | Atlas work or approved observation verified orally; synthetic data only |

Only Module 3's validation script is present in the package version reviewed while authoring this guide. If other inline validation controls are not backed by deployed validation scripts, grade those modules manually with the commands above rather than treating a missing validator as learner failure.

## End-of-lab instructor reset

Review packaged helpers before execution; helper names can vary with bootstrap version:

```bash
sudo find "$LAB_ROOT/reset" -maxdepth 1 -type f -printf '%f\n'
sudo grep -RIl 'seed\|restore\|authorization\|mongod' "$LAB_ROOT/reset" 2>/dev/null
```

Recommended order:

1. Preserve graded evidence if required.
2. Recover `mongod`: `sudo systemctl enable --now mongod`.
3. If authorization is enabled, use known admin credentials or the packaged auth reset helper.
4. Run the packaged seed reset helper to restore original customers/orders.
5. Remove learner-created backup/evidence artifacts only after grading.
6. Confirm service, database counts, local bind configuration, and absence of exposed TCP 27017.

```bash
systemctl is-active mongod
systemctl is-enabled mongod
sudo ss -ltnp | grep ':27017'
sudo grep -nE 'bindIp|port|authorization' /etc/mongod.conf
mongosh customer360 --quiet --eval 'printjson({customers:db.customers.countDocuments(),orders:db.orders.countDocuments()})'
```

If authorization remains enabled, run the final query with the admin authentication options. Do not manually delete the Azure resource group unless the CloudLabs operations process directs it; sandbox lifecycle cleanup normally handles Azure resources. If Azure-side teardown fails, confirm locks, RBAC scope/propagation, and soft-delete behavior for the specific resource type before retrying. Avoid repeated rapid resize/redeploy operations that can trigger regional capacity or storage throttling issues.