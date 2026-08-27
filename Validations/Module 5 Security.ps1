using namespace System.Net

# Note: $sub (subscription id) and $DID (deployment id) are injected by the platform.
$rg = "rg-mongodb-customer-data-$DID"
$count = 0
$found = $false
$lastFailure = "Module 5 security configuration has not been validated yet."

$script = @'
set -u

MONGOD_CONF="/etc/mongod.conf"

fail() {
  echo "VALIDATION_FAILED: $1"
  exit "$2"
}

# 1. mongod must be active
if ! systemctl is-active --quiet mongod; then
  fail "mongod service is not active." 20
fi

# 2. authorization: enabled must be configured
if [ ! -f "$MONGOD_CONF" ]; then
  fail "MongoDB configuration file '$MONGOD_CONF' was not found." 21
fi

if ! grep -Eq '^[[:space:]]*authorization:[[:space:]]*enabled[[:space:]]*$' "$MONGOD_CONF"; then
  fail "MongoDB authorization is not enabled in '$MONGOD_CONF'." 22
fi

# 3. Unauthenticated access must be denied
UNAUTH_OUTPUT=$(mongosh customer360 --quiet --eval '
try {
  db.customers.findOne();
  print("UNAUTHENTICATED_ACCESS_SUCCEEDED");
  quit(23);
} catch (e) {
  print("UNAUTHENTICATED_ACCESS_DENIED:" + e.message);
  quit(0);
}
' 2>&1)
UNAUTH_RC=$?

if [ "$UNAUTH_RC" -ne 0 ] || \
   ! printf '%s\n' "$UNAUTH_OUTPUT" | grep -q 'UNAUTHENTICATED_ACCESS_DENIED'; then
  fail "Unauthenticated access to customer360 was not denied. Output: $UNAUTH_OUTPUT" 23
fi

# 4. c360Admin must exist with root@admin
ADMIN_OUTPUT=$(mongosh admin --quiet --eval '
try {
  const user = db.getUser("c360Admin");

  if (!user) {
    print("ADMIN_NOT_FOUND");
    quit(24);
  }

  const roles = user.roles || [];

  const valid = roles.some(
    r => r.role === "root" && r.db === "admin"
  );

  if (!valid) {
    print("ADMIN_ROLE_INVALID:" + JSON.stringify(roles));
    quit(25);
  }

  print("ADMIN_VALID");
} catch (e) {
  print("ADMIN_CHECK_FAILED:" + e.message);
  quit(26);
}
' 2>&1)
ADMIN_RC=$?

if [ "$ADMIN_RC" -ne 0 ] || \
   ! printf '%s\n' "$ADMIN_OUTPUT" | grep -q '^ADMIN_VALID$'; then
  fail "c360Admin does not exist with the required root@admin role. Output: $ADMIN_OUTPUT" 24
fi

# 5. c360Reporter must exist with exactly read@customer360
REPORTER_OUTPUT=$(mongosh customer360 --quiet --eval '
try {
  const user = db.getUser("c360Reporter");

  if (!user) {
    print("REPORTER_NOT_FOUND");
    quit(27);
  }

  const roles = user.roles || [];

  const valid =
    roles.length === 1 &&
    roles[0].role === "read" &&
    roles[0].db === "customer360";

  if (!valid) {
    print("REPORTER_ROLE_INVALID:" + JSON.stringify(roles));
    quit(28);
  }

  print("REPORTER_VALID");
} catch (e) {
  print("REPORTER_CHECK_FAILED:" + e.message);
  quit(29);
}
' 2>&1)
REPORTER_RC=$?

if [ "$REPORTER_RC" -ne 0 ] || \
   ! printf '%s\n' "$REPORTER_OUTPUT" | grep -q '^REPORTER_VALID$'; then
  fail "c360Reporter does not exist with exactly read@customer360. Output: $REPORTER_OUTPUT" 27
fi

echo "VALIDATION_SUCCEEDED: Module 5 security requirements passed."
echo "mongod=active"
echo "authorization=enabled"
echo "unauthenticatedAccess=denied"
echo "c360Admin=root@admin"
echo "c360Reporter=read@customer360"
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
                    Message = "Module 5 validation passed on VM '$($vm.Name)' in RG '$rg'. $runOutput"
                } | ConvertTo-Json
            }
            else {
                $lastFailure = "Module 5 validation failed on VM '$($vm.Name)' in RG '$rg'. Output: $runOutput"
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
        $lastFailure = "Error during Module 5 security check. Attempt $count of 3. Error: $($_.Exception.Message)"

        $message = @{
            Status  = "Failed"
            Message = $lastFailure
        } | ConvertTo-Json

        Push-OutputBinding -Name Response -Value $message

        Start-Sleep -Seconds 10
    }

} while ($count -lt 3 -and -not $found)

if (-not $found) {
    $message = @{
        Status  = "Failed"
        Message = "Module 5 Security not validated in RG '$rg' after 3 attempts. Last result: $lastFailure"
    } | ConvertTo-Json

    Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
        StatusCode = [HttpStatusCode]::OK
        Body       = $message
    })
}