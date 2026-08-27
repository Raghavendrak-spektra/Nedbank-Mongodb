using namespace System.Net

# Note: $sub and $DID are injected by CloudLabs.
$rg = "rg-mongodb-customer-data-$DID"

$count = 0
$found = $false
$lastFailure = "Module 4 operational-support analytics validation has not run yet."

$script = @'
set -u

DB_NAME="customer360"
COLLECTION_NAME="orders"

SCRIPT_FILE="$HOME/mongodb-customer-data/scripts/analytics-report.mongodb.js"
OUTPUT_FILE="$HOME/mongodb-customer-data/evidence/m4-analytics-output.txt"

fail() {
  echo "VALIDATION_FAILED: $1"
  exit "${2:-1}"
}

echo "=== Module 4 Validation ==="

# ------------------------------------------------------------
# 1. Check mongosh
# ------------------------------------------------------------

if ! command -v mongosh >/dev/null 2>&1; then
  fail "mongosh is not installed or not in PATH." 20
fi

echo "PASS: mongosh is available."

# ------------------------------------------------------------
# 2. Check script exists
# ------------------------------------------------------------

if [ ! -f "$SCRIPT_FILE" ]; then
  fail "Required analytics script '$SCRIPT_FILE' was not found." 21
fi

if [ ! -s "$SCRIPT_FILE" ]; then
  fail "Analytics script '$SCRIPT_FILE' exists but is empty." 22
fi

echo "PASS: Analytics script exists and is not empty."

# ------------------------------------------------------------
# 3. Check required aggregation stages
# ------------------------------------------------------------

MISSING_STAGES=""

for STAGE in '$match' '$group' '$project' '$sort'; do
  if ! grep -qF "$STAGE" "$SCRIPT_FILE"; then
    MISSING_STAGES="$MISSING_STAGES $STAGE"
  fi
done

if [ -n "$MISSING_STAGES" ]; then
  fail "Analytics script is missing required aggregation stage(s):$MISSING_STAGES" 23
fi

echo "PASS: Script contains \$match, \$group, \$project, and \$sort."

# ------------------------------------------------------------
# 4. Check MongoDB database and collection
# ------------------------------------------------------------

DB_CHECK=$(mongosh "$DB_NAME" --quiet --eval '
const collection = db.getCollection("orders");

if (!collection) {
  print("COLLECTION_MISSING");
  quit(24);
}

print("COLLECTION_OK");
' 2>&1)

if ! printf '%s\n' "$DB_CHECK" | grep -q "COLLECTION_OK"; then
  fail "MongoDB collection customer360.orders could not be verified. Output: $DB_CHECK" 24
fi

echo "PASS: customer360.orders collection exists."

# ------------------------------------------------------------
# 5. Run the analytics script
# ------------------------------------------------------------

RUN_LOG="/tmp/m4-analytics-validation-$$.log"

mongosh --quiet "$SCRIPT_FILE" > "$RUN_LOG" 2>&1
MONGO_RC=$?

RUN_OUTPUT=$(cat "$RUN_LOG" 2>/dev/null)

if [ $MONGO_RC -ne 0 ]; then
  rm -f "$RUN_LOG"
  fail "Analytics script failed to execute. mongosh exit code: $MONGO_RC. Output: $RUN_OUTPUT" 25
fi

echo "PASS: Analytics script executed successfully."

# ------------------------------------------------------------
# 6. Create / refresh evidence output
# ------------------------------------------------------------

mkdir -p "$(dirname "$OUTPUT_FILE")"

mongosh --quiet "$SCRIPT_FILE" > "$OUTPUT_FILE" 2>&1
MONGO_OUTPUT_RC=$?

if [ $MONGO_OUTPUT_RC -ne 0 ]; then
  rm -f "$RUN_LOG"
  fail "Analytics script could not produce the required evidence output." 26
fi

if [ ! -f "$OUTPUT_FILE" ]; then
  rm -f "$RUN_LOG"
  fail "Required evidence file '$OUTPUT_FILE' was not created." 27
fi

if [ ! -s "$OUTPUT_FILE" ]; then
  rm -f "$RUN_LOG"
  fail "Evidence file '$OUTPUT_FILE' exists but is empty." 28
fi

echo "PASS: Evidence file exists and is not empty."

# ------------------------------------------------------------
# 7. Validate required report fields
# ------------------------------------------------------------

REQUIRED_FIELDS="
metricName
channel
status
orderCount
exceptionCount
exceptionAmount
latestExceptionDate
triagePriority
"

MISSING_FIELDS=""

for FIELD in $REQUIRED_FIELDS; do
  if ! grep -q "$FIELD" "$OUTPUT_FILE"; then
    MISSING_FIELDS="$MISSING_FIELDS $FIELD"
  fi
done

if [ -n "$MISSING_FIELDS" ]; then
  rm -f "$RUN_LOG"
  fail "Evidence output is missing required report field(s):$MISSING_FIELDS" 29
fi

echo "PASS: All required report fields are present."

# ------------------------------------------------------------
# 8. Validate that actual report rows exist
# ------------------------------------------------------------

if ! grep -q "Operational support triage exceptions" "$OUTPUT_FILE"; then
  rm -f "$RUN_LOG"
  fail "Evidence output does not contain an operational support triage report row." 30
fi

echo "PASS: Operational support triage report rows are present."

# ------------------------------------------------------------
# 9. Validate numeric metric values
# ------------------------------------------------------------

if ! grep -Eq 'orderCount:[[:space:]]*[0-9]+' "$OUTPUT_FILE"; then
  rm -f "$RUN_LOG"
  fail "No numeric orderCount value was found in the report." 31
fi

if ! grep -Eq 'exceptionCount:[[:space:]]*[0-9]+' "$OUTPUT_FILE"; then
  rm -f "$RUN_LOG"
  fail "No numeric exceptionCount value was found in the report." 32
fi

if ! grep -Eq 'exceptionAmount:[[:space:]]*[0-9]+' "$OUTPUT_FILE"; then
  rm -f "$RUN_LOG"
  fail "No numeric exceptionAmount value was found in the report." 33
fi

echo "PASS: Required numeric metrics contain values."

# ------------------------------------------------------------
# 10. Validate triage priority
# ------------------------------------------------------------

if ! grep -Eq "triagePriority:[[:space:]]*['\"]?(high|standard)" "$OUTPUT_FILE"; then
  rm -f "$RUN_LOG"
  fail "Report does not contain a valid triagePriority value." 34
fi

echo "PASS: Valid triagePriority values found."

# ------------------------------------------------------------
# 11. Final validation
# ------------------------------------------------------------

OUTPUT_BYTES=$(wc -c < "$OUTPUT_FILE" | tr -d ' ')
OUTPUT_LINES=$(wc -l < "$OUTPUT_FILE" | tr -d ' ')
SCRIPT_BYTES=$(wc -c < "$SCRIPT_FILE" | tr -d ' ')

rm -f "$RUN_LOG"

echo ""
echo "=== VALIDATION SUCCEEDED ==="
echo "Script: $SCRIPT_FILE"
echo "Script size: $SCRIPT_BYTES bytes"
echo "Evidence: $OUTPUT_FILE"
echo "Evidence size: $OUTPUT_BYTES bytes"
echo "Evidence lines: $OUTPUT_LINES"
echo "Required stages: \$match, \$group, \$project, \$sort"
echo "Required fields: metricName, channel, status, orderCount, exceptionCount, exceptionAmount, latestExceptionDate, triagePriority"
echo "Report rows: present"
echo "Numeric metrics: present"
echo "Triage priority: present"

echo "VALIDATION_SUCCEEDED: Module 4 operational-support analytics report is valid."
'@

do {
    $count = $count + 1

    try {
        Set-AzContext -Subscription $sub -ErrorAction Stop

        $vm = Get-AzVM `
            -ResourceGroupName $rg `
            -ErrorAction Stop |
            Where-Object {
                $_.StorageProfile.OSDisk.OSType -eq 'Linux'
            } |
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

            $runOutput = (
                $result.Value |
                ForEach-Object { $_.Message }
            ) -join "`n"

            $runOutput = $runOutput.Trim()

            if ($runOutput -match 'VALIDATION_SUCCEEDED:') {
                $found = $true

                $message = @{
                    Status  = "Succeeded"
                    Message = "Module 4 validation passed on VM '$($vm.Name)' in RG '$rg'. $runOutput"
                } | ConvertTo-Json
            }
            else {
                $lastFailure = "Module 4 validation failed on VM '$($vm.Name)' in RG '$rg'. Run Command output: $runOutput"
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
        $lastFailure = "Error during Module 4 validation. Attempt $count of 3. Error: $($_.Exception.Message)"

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

# ------------------------------------------------------------
# Final failure response
# ------------------------------------------------------------

if (-not $found) {

    $message = @{
        Status  = "Failed"
        Message = "Module 4 Analytics was not validated in RG '$rg' after 3 attempts. Last result: $lastFailure"
    } | ConvertTo-Json

    Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
        StatusCode = [HttpStatusCode]::OK
        Body       = $message
    })
}