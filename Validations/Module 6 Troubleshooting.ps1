using namespace System.Net

# Note: $sub (subscription id) and $DID (deployment id) are injected by the platform.
$rg = "rg-mongodb-customer-data-$DID"
$count = 0
$found = $false
$lastFailure = "Module 6 troubleshooting evidence has not been validated yet."

$script = @'
set -u

DB_NAME="customer360"
EVIDENCE_FILE="/opt/cloudlabs/mongodb-customer-data/evidence/m6-incident-note.txt"

ACTIVE_STATE=$(systemctl is-active mongod 2>&1 || true)
if [ "$ACTIVE_STATE" != "active" ]; then
  echo "VALIDATION_FAILED: mongod service is not active. systemctl is-active returned '$ACTIVE_STATE'."
  exit 30
fi

ENABLED_STATE=$(systemctl is-enabled mongod 2>&1 || true)
if [ "$ENABLED_STATE" != "enabled" ]; then
  echo "VALIDATION_FAILED: mongod service is not enabled. systemctl is-enabled returned '$ENABLED_STATE'."
  exit 31
fi

if ! command -v mongosh >/dev/null 2>&1; then
  echo "VALIDATION_FAILED: mongosh is not installed or not in PATH."
  exit 32
fi

QUERY_OUTPUT=$(mongosh "$DB_NAME" --quiet --eval '
const customers = db.customers.countDocuments();
const orders = db.orders.countDocuments();
if (customers > 0 && orders > 0) {
  print("QUERY_OK:customers=" + customers + ";orders=" + orders);
} else {
  print("QUERY_FAILED: customers=" + customers + "; orders=" + orders);
  quit(33);
}
' 2>&1)
QUERY_RC=$?

if [ $QUERY_RC -ne 0 ]; then
  echo "VALIDATION_FAILED: customer360 query did not succeed. mongosh output: $QUERY_OUTPUT"
  exit 33
fi

if [ ! -f "$EVIDENCE_FILE" ]; then
  echo "VALIDATION_FAILED: Required incident evidence file '$EVIDENCE_FILE' was not found."
  exit 34
fi

if [ ! -s "$EVIDENCE_FILE" ]; then
  echo "VALIDATION_FAILED: Incident evidence file '$EVIDENCE_FILE' exists but is empty."
  exit 35
fi

if ! grep -qi "mongod" "$EVIDENCE_FILE" || ! grep -Eqi "stopped|disabled|service" "$EVIDENCE_FILE"; then
  echo "VALIDATION_FAILED: Incident evidence file '$EVIDENCE_FILE' must mention the mongod service incident and recovery diagnosis."
  exit 36
fi

EVIDENCE_BYTES=$(wc -c < "$EVIDENCE_FILE" | tr -d ' ')
QUERY_SUMMARY=$(printf '%s\n' "$QUERY_OUTPUT" | grep 'QUERY_OK:' | tail -n 1)
echo "VALIDATION_SUCCEEDED: mongod is active and enabled; $QUERY_SUMMARY; incident evidence file '$EVIDENCE_FILE' exists with $EVIDENCE_BYTES bytes."
'@

do {
    $count = $count + 1
    try {
        Set-AzContext -Subscription $sub -ErrorAction Stop

        $vm = Get-AzVM -ResourceGroupName $rg -ErrorAction Stop | Where-Object { $_.StorageProfile.OSDisk.OSType -eq 'Linux' } | Select-Object -First 1
        if (-not $vm) {
            $lastFailure = "No Linux virtual machine was found in resource group '$rg'."
            $found = $false
        }
        else {
            $result = Invoke-AzVMRunCommand -ResourceGroupName $rg -VMName $vm.Name -CommandId 'RunShellScript' -ScriptString $script -ErrorAction Stop
            $runOutput = (($result.Value | ForEach-Object { $_.Message }) -join "`n").Trim()

            if ($runOutput -match 'VALIDATION_SUCCEEDED:') {
                $found = $true
                $message = @{
                    Status  = "Succeeded"
                    Message = "Module 6 validation passed on VM '$($vm.Name)' in RG '$rg'. $runOutput"
                } | ConvertTo-Json
            }
            else {
                $lastFailure = "Module 6 validation failed on VM '$($vm.Name)' in RG '$rg'. Run command output: $runOutput"
                $found = $false
            }
        }

        if ($found) {
            Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
                StatusCode = [HttpStatusCode]::OK
                Body       = $message
            })
        } else {
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
        $lastFailure = "Error during Module 6 troubleshooting check. Attempt $count of 3. Error: $($_.Exception.Message)"
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
        Message = "Module 6 Troubleshooting not validated in RG '$rg' after 3 attempts. Last result: $lastFailure"
    } | ConvertTo-Json
    Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
        StatusCode = [HttpStatusCode]::OK
        Body       = $message
    })
}
