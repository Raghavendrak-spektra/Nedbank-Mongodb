using namespace System.Net 
 
# Note: $sub (subscription id) and $DID (deployment id) are injected by the platform. 
$rg = "rg-mongodb-customer-data-$DID" 
$count = 0 
$found = $false 
$lastFailure = "Module 2 backup and recovery evidence has not been validated yet." 
 
$script = @'
set -u

WORK_ROOT="$HOME/mongodb-customer-data"
BACKUP_ROOT="${WORK_ROOT}/backups"
EVIDENCE_ROOT="${WORK_ROOT}/evidence"
SUBSET_FILE="${EVIDENCE_ROOT}/m2-subset-ids.json"

fail() {
  echo "VALIDATION_FAILED: $1"
  exit "${2:-1}"
}

# Check main working directory
if [ ! -d "$WORK_ROOT" ]; then
  fail "Required directory '$WORK_ROOT' was not found." 20
fi

# Check backup directory
if [ ! -d "$BACKUP_ROOT" ]; then
  fail "Backup directory '$BACKUP_ROOT' was not found." 21
fi

# Find latest customer360 backup
LATEST_BACKUP=$(find "$BACKUP_ROOT" \
  -maxdepth 1 \
  -type d \
  -name 'customer360-*' \
  2>/dev/null | sort | tail -n 1)

if [ -z "$LATEST_BACKUP" ]; then
  fail "No timestamped customer360 backup directory was found under '$BACKUP_ROOT'." 22
fi

# Check customers backup
CUSTOMERS_BSON="${LATEST_BACKUP}/customer360/customers.bson"

if [ ! -s "$CUSTOMERS_BSON" ]; then
  fail "Backup artifact '$CUSTOMERS_BSON' was not found or is empty." 23
fi

# Check recovery subset evidence
if [ ! -s "$SUBSET_FILE" ]; then
  fail "Recovery subset evidence '$SUBSET_FILE' was not found or is empty." 24
fi

# Check that the subset evidence contains IDs
if ! grep -q '"ids"' "$SUBSET_FILE"; then
  fail "Recovery subset evidence '$SUBSET_FILE' does not contain an 'ids' field." 25
fi

# Check temporary MongoDB recovery database
MONGO_OUTPUT=$(mongosh --quiet --eval '
const recovery = db.getSiblingDB("customer360_recovery");
const collections = recovery.getCollectionNames();

if (!collections.includes("customers")) {
  print("RECOVERY_DB_MISSING");
  quit(26);
}

const customerCount = recovery.customers.countDocuments();

print("RECOVERY_DB_FOUND");
print("RECOVERY_CUSTOMER_COUNT:" + customerCount);
' 2>&1)

MONGO_RC=$?

if [ $MONGO_RC -ne 0 ]; then
  fail "Temporary recovery database 'customer360_recovery' was not found or does not contain the customers collection. mongosh output: $MONGO_OUTPUT" 26
fi

if ! printf '%s\n' "$MONGO_OUTPUT" | grep -q "RECOVERY_DB_FOUND"; then
  fail "Temporary recovery database validation failed. mongosh output: $MONGO_OUTPUT" 27
fi

CUSTOMERS_BSON_BYTES=$(wc -c < "$CUSTOMERS_BSON" | tr -d ' ')
SUBSET_BYTES=$(wc -c < "$SUBSET_FILE" | tr -d ' ')
RECOVERY_CUSTOMER_COUNT=$(printf '%s\n' "$MONGO_OUTPUT" |
  grep '^RECOVERY_CUSTOMER_COUNT:' |
  cut -d':' -f2)

echo "VALIDATION_SUCCEEDED: Module 2 validation passed. Backup '$LATEST_BACKUP' contains customers.bson (${CUSTOMERS_BSON_BYTES} bytes), recovery subset evidence '$SUBSET_FILE' exists (${SUBSET_BYTES} bytes), and temporary recovery database 'customer360_recovery' contains the customers collection with ${RECOVERY_CUSTOMER_COUNT} documents."
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
                    Message = "Module 2 validation passed on VM '$($vm.Name)' in RG '$rg'. $runOutput" 
                } | ConvertTo-Json 
            } 
            else { 
                $lastFailure = "Module 2 validation failed on VM '$($vm.Name)' in RG '$rg'. Run command output: $runOutput" 
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
        $lastFailure = "Error during Module 2 backup recovery check. Attempt $count of 3. Error: $($_.Exception.Message)" 
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
        Message = "Module 2 Backup Recovery not validated in RG '$rg' after 3 attempts. Last result: $lastFailure" 
    } | ConvertTo-Json 
    Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{ 
        StatusCode = [HttpStatusCode]::OK 
        Body       = $message 
    }) 
}