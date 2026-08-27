using namespace System.Net

# Note: $sub (subscription id) and $DID (deployment id) are injected by the platform.
$rg = "rg-mongodb-customer-data-$DID"
$count = 0
$found = $false
$lastFailure = "Module 7 Atlas operations evidence has not been validated yet."

$script = @'
set -u

EVIDENCE_FILE="/opt/cloudlabs/mongodb-customer-data/evidence/atlas-operations-evidence.txt"

if [ ! -f "$EVIDENCE_FILE" ]; then
  echo "VALIDATION_FAILED: Required Atlas operations evidence file '$EVIDENCE_FILE' was not found."
  exit 70
fi

if [ ! -s "$EVIDENCE_FILE" ]; then
  echo "VALIDATION_FAILED: Atlas operations evidence file '$EVIDENCE_FILE' exists but is empty."
  exit 71
fi

FILE_SIZE=$(wc -c < "$EVIDENCE_FILE" | tr -d ' ')
if [ "$FILE_SIZE" -lt 100 ]; then
  echo "VALIDATION_FAILED: Atlas operations evidence file '$EVIDENCE_FILE' is too small ($FILE_SIZE bytes) to contain the required fields."
  exit 72
fi

if [ "$FILE_SIZE" -gt 20000 ]; then
  echo "VALIDATION_FAILED: Atlas operations evidence file '$EVIDENCE_FILE' is unexpectedly large ($FILE_SIZE bytes). Keep only concise non-secret operational evidence."
  exit 73
fi

SECRET_PATTERNS='mongodb(\+srv)?://|[A-Za-z][A-Za-z0-9+.-]*://[^[:space:]]+:[^[:space:]]+@|password[[:space:]]*[:=]|passwd[[:space:]]*[:=]|pwd[[:space:]]*[:=]|api[ _-]?key[[:space:]]*[:=]|authorization[[:space:]]*:[[:space:]]*(basic|bearer)|BEGIN[[:space:]]+[A-Z ]*PRIVATE[[:space:]]+KEY|private[ _-]?key[[:space:]]*[:=]|secret[[:space:]]*[:=]|client[ _-]?secret[[:space:]]*[:=]'
SECRET_MATCH=$(grep -Ein "$SECRET_PATTERNS" "$EVIDENCE_FILE" | head -n 3 || true)
if [ -n "$SECRET_MATCH" ]; then
  echo "VALIDATION_FAILED: Atlas evidence appears to contain a secret, full connection string, credential URI, API key, password, bearer/basic authorization header, or private key pattern. Remove the sensitive content. Matching line(s): $SECRET_MATCH"
  exit 74
fi

get_field_value() {
  field_name="$1"
  awk -v key="$field_name" '
    BEGIN { FS=":"; found=0 }
    tolower($1) == tolower(key) {
      sub(/^[^:]*:[[:space:]]*/, "")
      print
      found=1
      exit
    }
  ' "$EVIDENCE_FILE"
}

REQUIRED_FIELDS="Atlas Project Name|Atlas Cluster Name|Connection Method Used|Network Access Approach|Database Access Role Observed|Sample Data Action|Security Setting Reviewed|Monitoring Metric Reviewed|Backup Setting Observed|Troubleshooting Note|Secrets Stored"
MISSING_FIELDS=""
PLACEHOLDER_FIELDS=""

OLD_IFS="$IFS"
IFS='|'
for FIELD in $REQUIRED_FIELDS; do
  VALUE=$(get_field_value "$FIELD" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
  if [ -z "$VALUE" ]; then
    if [ -z "$MISSING_FIELDS" ]; then
      MISSING_FIELDS="$FIELD"
    else
      MISSING_FIELDS="$MISSING_FIELDS, $FIELD"
    fi
  else
    VALUE_LOWER=$(printf '%s' "$VALUE" | tr '[:upper:]' '[:lower:]')
    case "$VALUE_LOWER" in
      pending|todo|tbd|replace|replace_me|changeme|change_me|none|n/a|na)
        if [ -z "$PLACEHOLDER_FIELDS" ]; then
          PLACEHOLDER_FIELDS="$FIELD"
        else
          PLACEHOLDER_FIELDS="$PLACEHOLDER_FIELDS, $FIELD"
        fi
        ;;
    esac
  fi
done
IFS="$OLD_IFS"

if [ -n "$MISSING_FIELDS" ]; then
  echo "VALIDATION_FAILED: Atlas operations evidence is missing required field(s): $MISSING_FIELDS."
  exit 75
fi

if [ -n "$PLACEHOLDER_FIELDS" ]; then
  echo "VALIDATION_FAILED: Atlas operations evidence still has placeholder or incomplete value(s) for: $PLACEHOLDER_FIELDS."
  exit 76
fi

SECRETS_STORED=$(get_field_value "Secrets Stored" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | tr '[:upper:]' '[:lower:]')
if [ "$SECRETS_STORED" != "no" ]; then
  echo "VALIDATION_FAILED: The 'Secrets Stored' field must be exactly 'No' after removing all passwords, API keys, private keys, and full connection strings. Current value: '$SECRETS_STORED'."
  exit 77
fi

PROJECT_VALUE=$(get_field_value "Atlas Project Name" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
CLUSTER_VALUE=$(get_field_value "Atlas Cluster Name" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
CONNECTION_VALUE=$(get_field_value "Connection Method Used" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
BACKUP_VALUE=$(get_field_value "Backup Setting Observed" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
TROUBLE_VALUE=$(get_field_value "Troubleshooting Note" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

SUMMARY="Project='$PROJECT_VALUE'; Cluster='$CLUSTER_VALUE'; ConnectionMethod='$CONNECTION_VALUE'; BackupObservation='$BACKUP_VALUE'; TroubleshootingNoteLength=${#TROUBLE_VALUE}; EvidenceBytes=$FILE_SIZE"
echo "VALIDATION_SUCCEEDED: Atlas operations evidence file '$EVIDENCE_FILE' contains all required non-secret fields, has Secrets Stored set to No, and no obvious secret/full-connection-string patterns were detected. $SUMMARY"
'@

do {
    $count = $count + 1
    try {
        Set-AzContext -Subscription $sub -ErrorAction Stop

        $preferredVmName = "labvm-$DID"
        $vm = Get-AzVM -ResourceGroupName $rg -Name $preferredVmName -ErrorAction SilentlyContinue
        if (-not $vm) {
            $vm = Get-AzVM -ResourceGroupName $rg -ErrorAction Stop | Where-Object { $_.StorageProfile.OSDisk.OSType -eq 'Linux' } | Select-Object -First 1
        }

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
                    Message = "Module 7 validation passed on VM '$($vm.Name)' in RG '$rg'. $runOutput"
                } | ConvertTo-Json
            }
            else {
                $lastFailure = "Module 7 validation failed on VM '$($vm.Name)' in RG '$rg'. Run command output: $runOutput"
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
        $lastFailure = "Error during Module 7 Atlas operations evidence check. Attempt $count of 3. Error: $($_.Exception.Message)"
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
        Message = "Module 7 Atlas Operations evidence not validated in RG '$rg' after 3 attempts. Last result: $lastFailure"
    } | ConvertTo-Json
    Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
        StatusCode = [HttpStatusCode]::OK
        Body       = $message
    })
}
