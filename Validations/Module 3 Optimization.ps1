using namespace System.Net

# Note: $sub (subscription id) and $DID (deployment id) are injected by the platform.
$rg = "rg-mongodb-customer-data-$DID"
$count = 0
$found = $false
$lastFailure = "Module 3 optimization evidence has not been validated yet."

$script = @'
set -u

DB_NAME="customer360"
COLLECTION_NAME="orders"
EVIDENCE_FILE="$HOME/mongodb-customer-data/evidence/module3-explain-evidence.txt"

fail() {
  echo "VALIDATION_FAILED: $1"
  exit "${2:-1}"
}

echo "=== Module 3 Validation ==="

# ------------------------------------------------------------
# 1. Check mongosh
# ------------------------------------------------------------

if ! command -v mongosh >/dev/null 2>&1; then
  fail "mongosh is not installed or not in PATH." 20
fi

echo "PASS: mongosh is available."

# ------------------------------------------------------------
# 2. Check evidence file
# ------------------------------------------------------------

if [ ! -f "$EVIDENCE_FILE" ]; then
  fail "Required evidence file '$EVIDENCE_FILE' was not found." 21
fi

if [ ! -s "$EVIDENCE_FILE" ]; then
  fail "Evidence file '$EVIDENCE_FILE' exists but is empty." 22
fi

echo "PASS: Evidence file exists and is not empty."

# ------------------------------------------------------------
# 3. Validate BEFORE evidence
# ------------------------------------------------------------

if ! grep -q "MODULE3_BASELINE" "$EVIDENCE_FILE"; then
  fail "Evidence file does not contain MODULE3_BASELINE evidence." 23
fi

echo "PASS: BEFORE baseline explain evidence found."

# ------------------------------------------------------------
# 4. Validate AFTER evidence
# ------------------------------------------------------------

if ! grep -q "AFTER explain optimized" "$EVIDENCE_FILE"; then
  fail "Evidence file does not contain AFTER explain optimized evidence." 24
fi

echo "PASS: AFTER optimized explain evidence found."

# ------------------------------------------------------------
# 5. Validate explain statistics exist
# ------------------------------------------------------------

if ! grep -q "nReturned:" "$EVIDENCE_FILE"; then
  fail "Evidence file does not contain nReturned statistics." 25
fi

if ! grep -q "totalKeysExamined:" "$EVIDENCE_FILE"; then
  fail "Evidence file does not contain totalKeysExamined statistics." 26
fi

if ! grep -q "totalDocsExamined:" "$EVIDENCE_FILE"; then
  fail "Evidence file does not contain totalDocsExamined statistics." 27
fi

if ! grep -q "executionTimeMillis:" "$EVIDENCE_FILE"; then
  fail "Evidence file does not contain executionTimeMillis statistics." 28
fi

echo "PASS: Explain execution statistics found."

# ------------------------------------------------------------
# 6. Validate learner-created Module 3 index
# ------------------------------------------------------------

INDEX_CHECK=$(mongosh "$DB_NAME" --quiet --eval '
const collection = db.getCollection("orders");

const indexes = collection.getIndexes();

const matches = indexes.filter(i => {
  if (i.name === "_id_") {
    return false;
  }

  if (!i.name.startsWith("m3_")) {
    return false;
  }

  const key = i.key || {};

  /*
   * Required Module 3 fields:
   *
   * status: 1
   * orderDate: -1
   *
   * Additional fields are allowed.
   */
  return key.status === 1 && key.orderDate === -1;
});

if (matches.length === 0) {
  print("INDEX_MISSING");

  print("Available indexes:");
  print(EJSON.stringify(
    indexes.map(i => ({
      name: i.name,
      key: i.key
    })),
    null,
    2
  ));

  quit(29);
}

for (const index of matches) {
  print(
    "INDEX_OK:" +
    index.name +
    ":" +
    EJSON.stringify(index.key)
  );
}
' 2>&1)

MONGO_RC=$?

if [ $MONGO_RC -ne 0 ]; then
  echo "$INDEX_CHECK"
  fail "Required Module 3 index was not found. Expected an m3_ index containing status:1 and orderDate:-1." 29
fi

INDEX_LINE=$(printf '%s\n' "$INDEX_CHECK" | grep '^INDEX_OK:' | head -n 1)

if [ -z "$INDEX_LINE" ]; then
  fail "No valid Module 3 performance index was found." 30
fi

INDEX_NAME=$(printf '%s' "$INDEX_LINE" | cut -d':' -f2)
INDEX_KEY=$(printf '%s' "$INDEX_LINE" | cut -d':' -f3-)

echo "PASS: Module 3 performance index found."
echo "Index name: $INDEX_NAME"
echo "Index key:  $INDEX_KEY"

# ------------------------------------------------------------
# 7. Validate that AFTER evidence shows the Module 3 index
# ------------------------------------------------------------

if ! grep -q "winningPlanIndexName: $INDEX_NAME" "$EVIDENCE_FILE"; then
  fail "AFTER explain evidence does not show the Module 3 index '$INDEX_NAME' being used." 31
fi

echo "PASS: AFTER explain evidence shows index '$INDEX_NAME' being used."

# ------------------------------------------------------------
# 8. Extract BEFORE and AFTER document counts
# ------------------------------------------------------------

BEFORE_DOCS=$(awk '
/MODULE3_BASELINE/ { section="before"; next }
/AFTER explain optimized/ { section="after"; next }
section=="before" && /totalDocsExamined:/ {
  value=$0
  sub(/^.*totalDocsExamined:[[:space:]]*/, "", value)
  print value
  exit
}
' "$EVIDENCE_FILE")

AFTER_DOCS=$(awk '
/AFTER explain optimized/ { section="after"; next }
section=="after" && /totalDocsExamined:/ {
  value=$0
  sub(/^.*totalDocsExamined:[[:space:]]*/, "", value)
  print value
  exit
}
' "$EVIDENCE_FILE")

# ------------------------------------------------------------
# 9. Validate that statistics are numeric
# ------------------------------------------------------------

case "$BEFORE_DOCS" in
  ''|*[!0-9]*)
    fail "Could not parse numeric BEFORE totalDocsExamined from evidence." 32
    ;;
esac

case "$AFTER_DOCS" in
  ''|*[!0-9]*)
    fail "Could not parse numeric AFTER totalDocsExamined from evidence." 33
    ;;
esac

echo "BEFORE totalDocsExamined: $BEFORE_DOCS"
echo "AFTER  totalDocsExamined: $AFTER_DOCS"

# ------------------------------------------------------------
# 10. Validate optimization improvement
# ------------------------------------------------------------

if [ "$AFTER_DOCS" -ge "$BEFORE_DOCS" ]; then
  fail "Optimization evidence did not reduce totalDocsExamined. BEFORE=$BEFORE_DOCS, AFTER=$AFTER_DOCS." 34
fi

echo "PASS: totalDocsExamined improved from $BEFORE_DOCS to $AFTER_DOCS."

# ------------------------------------------------------------
# 11. Final success
# ------------------------------------------------------------

EVIDENCE_BYTES=$(wc -c < "$EVIDENCE_FILE" | tr -d ' ')

echo ""
echo "=== VALIDATION SUCCEEDED ==="
echo "Evidence file: $EVIDENCE_FILE"
echo "Index name:    $INDEX_NAME"
echo "Index key:     $INDEX_KEY"
echo "Before docs:   $BEFORE_DOCS"
echo "After docs:    $AFTER_DOCS"
echo "Evidence size: $EVIDENCE_BYTES bytes"

echo ""
echo "VALIDATION_SUCCEEDED: Module 3 optimization is validated. Learner-created index '$INDEX_NAME' exists on customer360.orders, the AFTER explain evidence shows the index is used, and totalDocsExamined improved from $BEFORE_DOCS to $AFTER_DOCS."
'@

do {
    $count = $count + 1
    try {
        Set-AzContext -Subscription $sub -ErrorAction Stop

        $vm = Get-AzVM -ResourceGroupName $rg -ErrorAction Stop |
            Where-Object { $_.StorageProfile.OSDisk.OSType -eq 'Linux' } |
            Select-Object -First 1

        if (-not $vm) {
            $lastFailure = "No Linux virtual machine was found in resource group '$rg'."
            $found = $false
        }
        else {
            $result = Invoke-AzVMRunCommand `
                -ResourceGroupName $rg `
                -VMName $vm.Name `
                -CommandId 'RunShellScript' `
                -ScriptString $script `
                -ErrorAction Stop

            $runOutput = (($result.Value |
                ForEach-Object { $_.Message }) -join "`n").Trim()

            if ($runOutput -match 'VALIDATION_SUCCEEDED:') {
                $found = $true

                $message = @{
                    Status  = "Succeeded"
                    Message = "Module 3 validation passed on VM '$($vm.Name)' in RG '$rg'. $runOutput"
                } | ConvertTo-Json
            }
            else {
                $lastFailure = "Module 3 validation failed on VM '$($vm.Name)' in RG '$rg'. Run command output: $runOutput"
                $found = $false
            }
        }

        if ($found) {
            Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
                StatusCode = [HttpStatusCode]::OK
                Body       = $message
            })
        }
        else {
            $message = @{
                Status  = "Failed"
                Message = $lastFailure
            } | ConvertTo-Json

            Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
                StatusCode = [HttpStatusCode]::OK
                Body       = $message
            })

            Start-Sleep -Seconds 10
        }
    }
    catch {
        $lastFailure = "Error during Module 3 optimization check. Attempt $count of 3. Error: $($_.Exception.Message)"

        $message = @{
            Status  = "Failed"
            Message = $lastFailure
        } | ConvertTo-Json

        Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
            StatusCode = [HttpStatusCode]::OK
            Body       = $message
        })

        Start-Sleep -Seconds 10
    }
} while ($count -lt 3 -and -not $found)

# Post-loop: if every attempt failed, emit a final failure JSON so CloudLabs
# always sees a structured result.
if (-not $found) {
    $message = @{
        Status  = "Failed"
        Message = "Module 3 Optimization not validated in RG '$rg' after 3 attempts. Last result: $lastFailure"
    } | ConvertTo-Json

    Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
        StatusCode = [HttpStatusCode]::OK
        Body       = $message
    })
}