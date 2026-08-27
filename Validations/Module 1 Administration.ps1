using namespace System.Net

# Note: $sub (subscription id) and $DID (deployment id) are injected by the platform.
$rg = "rg-mongodb-customer-data-$DID"
$count = 0
$found = $false
$lastFailure = "Module 1 administration checks have not been validated yet."

$script = @'
set -u

if ! command -v mongosh >/dev/null 2>&1; then
  echo "VALIDATION_FAILED: mongosh is not installed or not in PATH."
  exit 20
fi

CHECK_OUTPUT=$(mongosh --quiet --eval '
const dbName = "customer360";
const requiredCollections = ["customers", "orders", "audit_events"];
const candidateId = "CUST-ASSESS-M1";

function fail(message, code) {
  print("VALIDATION_FAILED: " + message);
  quit(code);
}

try {
  // ------------------------------------------------------------
  // 1. MongoDB connectivity
  // ------------------------------------------------------------
  const ping = db.getSiblingDB("admin").runCommand({ ping: 1 });

  if (!ping || ping.ok !== 1) {
    fail("MongoDB ping did not return ok: 1.", 31);
  }

  // ------------------------------------------------------------
  // 2. Database existence
  // ------------------------------------------------------------
  const databaseNames = db.getMongo().getDBNames();

  if (!databaseNames.includes(dbName)) {
    fail(
      "Database customer360 was not found. Databases visible: " +
      databaseNames.join(", "),
      32
    );
  }

  const cdb = db.getSiblingDB(dbName);

  // ------------------------------------------------------------
  // 3. Required collections
  // ------------------------------------------------------------
  const existingCollections = cdb.getCollectionNames();

  const missingCollections = requiredCollections.filter(
    c => !existingCollections.includes(c)
  );

  if (missingCollections.length > 0) {
    fail(
      "Missing required collection(s) in customer360: " +
      missingCollections.join(", "),
      33
    );
  }

  // ------------------------------------------------------------
  // 4. Assessment customer exists exactly once
  // ------------------------------------------------------------
  const candidateCount = cdb.customers.countDocuments({
    customerId: candidateId
  });

  if (candidateCount !== 1) {
    fail(
      "Expected exactly one customer with customerId CUST-ASSESS-M1, found " +
      candidateCount + ".",
      34
    );
  }

  const candidate = cdb.customers.findOne({
    customerId: candidateId
  });

  // ------------------------------------------------------------
  // 5. Validate final customer values
  // ------------------------------------------------------------
  const candidateProblems = [];

  if (candidate.email !== "candidate.m1@contoso-retail.example") {
    candidateProblems.push(
      "email is not candidate.m1@contoso-retail.example"
    );
  }

  if (candidate.region !== "West") {
    candidateProblems.push("region is not West");
  }

  if (candidate.loyaltyTier !== "Gold") {
    candidateProblems.push("loyaltyTier is not Gold");
  }

  if (candidate.status !== "inactive") {
    candidateProblems.push("status is not inactive");
  }

  if (
    !candidate.consent ||
    candidate.consent.marketing !== true
  ) {
    candidateProblems.push(
      "consent.marketing is not Boolean true"
    );
  }

  if (
    !candidate.consent ||
    candidate.consent.supportContact !== true
  ) {
    candidateProblems.push(
      "consent.supportContact is not Boolean true"
    );
  }

  if (candidateProblems.length > 0) {
    fail(
      "Assessment customer CUST-ASSESS-M1 has incorrect final values: " +
      candidateProblems.join("; ") +
      ".",
      35
    );
  }

  // ------------------------------------------------------------
  // 6. Read customers collection metadata
  // ------------------------------------------------------------
  const customerInfo = cdb.getCollectionInfos({
    name: "customers"
  });

  if (!customerInfo || customerInfo.length !== 1) {
    fail(
      "Collection metadata for customer360.customers could not be read.",
      36
    );
  }

  const options = customerInfo[0].options || {};
  const validator = options.validator;

  // ------------------------------------------------------------
  // 7. Validator must exist and use $jsonSchema
  // ------------------------------------------------------------
  if (!validator || !validator.$jsonSchema) {
    fail(
      "The customers collection does not have the required $jsonSchema validator.",
      37
    );
  }

  const schema = validator.$jsonSchema;

  // ------------------------------------------------------------
  // 8. Required validator fields
  // ------------------------------------------------------------
  const requiredFields = [
    "customerId",
    "email",
    "region",
    "loyaltyTier",
    "status",
    "consent"
  ];

  if (!Array.isArray(schema.required)) {
    fail(
      "The customers validator does not define required fields.",
      38
    );
  }

  for (const field of requiredFields) {
    if (!schema.required.includes(field)) {
      fail(
        "The customers validator is missing required field: " +
        field + ".",
        38
      );
    }
  }

  // ------------------------------------------------------------
  // 9. Validate string types
  // ------------------------------------------------------------
  if (
    !schema.properties ||
    !schema.properties.email ||
    schema.properties.email.bsonType !== "string"
  ) {
    fail(
      "The customers validator must require email to be a string.",
      39
    );
  }

  if (
    !schema.properties.region ||
    schema.properties.region.bsonType !== "string"
  ) {
    fail(
      "The customers validator must require region to be a string.",
      39
    );
  }

  if (
    !schema.properties.loyaltyTier ||
    schema.properties.loyaltyTier.bsonType !== "string"
  ) {
    fail(
      "The customers validator must require loyaltyTier to be a string.",
      39
    );
  }

  // ------------------------------------------------------------
  // 10. Validate status rule
  // ------------------------------------------------------------
  const statusRule =
    schema.properties &&
    schema.properties.status;

  if (!statusRule) {
    fail(
      "The customers validator does not define a status rule.",
      40
    );
  }

  if (statusRule.bsonType !== "string") {
    fail(
      "The customers validator must require status to be a string.",
      40
    );
  }

  if (
    !Array.isArray(statusRule.enum) ||
    statusRule.enum.length !== 2 ||
    !statusRule.enum.includes("active") ||
    !statusRule.enum.includes("inactive")
  ) {
    fail(
      "The customers validator must restrict status to active or inactive.",
      40
    );
  }

  // ------------------------------------------------------------
  // 11. Validate consent rules
  // ------------------------------------------------------------
  const consentRule =
    schema.properties &&
    schema.properties.consent;

  if (!consentRule || consentRule.bsonType !== "object") {
    fail(
      "The customers validator must define consent as an object.",
      41
    );
  }

  if (
    !Array.isArray(consentRule.required) ||
    !consentRule.required.includes("marketing") ||
    !consentRule.required.includes("supportContact")
  ) {
    fail(
      "The customers validator must require consent.marketing and consent.supportContact.",
      41
    );
  }

  if (
    !consentRule.properties ||
    !consentRule.properties.marketing ||
    consentRule.properties.marketing.bsonType !== "bool"
  ) {
    fail(
      "The customers validator must require consent.marketing to be Boolean.",
      41
    );
  }

  if (
    !consentRule.properties ||
    !consentRule.properties.supportContact ||
    consentRule.properties.supportContact.bsonType !== "bool"
  ) {
    fail(
      "The customers validator must require consent.supportContact to be Boolean.",
      41
    );
  }

  // ------------------------------------------------------------
  // 12. Validate enforcement settings
  // ------------------------------------------------------------
  if (options.validationLevel !== "strict") {
    fail(
      "The customers validationLevel is " +
      options.validationLevel +
      ", expected strict.",
      42
    );
  }

  if (options.validationAction !== "error") {
    fail(
      "The customers validationAction is " +
      options.validationAction +
      ", expected error.",
      43
    );
  }

  // ------------------------------------------------------------
  // 13. Behavioral validator test
  // ------------------------------------------------------------
  const testId =
    "CUST-VALIDATION-TEST-M1-" +
    new Date().getTime();

  let rejected = false;

  try {
    cdb.customers.insertOne({
      customerId: testId,
      email: "validation-test@example.com",
      region: "West",
      loyaltyTier: "Silver",
      status: "pending",
      consent: {
        marketing: true,
        supportContact: true
      }
    });

    fail(
      "Validator did not reject invalid status 'pending'.",
      44
    );

  } catch (err) {
    if (err && err.code === 121) {
      rejected = true;
    }
    else if (
      err &&
      err.message &&
      err.message.includes(
        "Validator did not reject invalid status"
      )
    ) {
      throw err;
    }
    else {
      fail(
        "Validator behavior test failed unexpectedly: " +
        err.message,
        45
      );
    }
  }

  if (!rejected) {
    fail(
      "Invalid status 'pending' was not rejected by the validator.",
      46
    );
  }

  // ------------------------------------------------------------
  // 14. Confirm negative test left no record
  // ------------------------------------------------------------
  const testCount = cdb.customers.countDocuments({
    customerId: testId
  });

  if (testCount !== 0) {
    cdb.customers.deleteMany({
      customerId: testId
    });

    fail(
      "Negative validation test left a temporary customer record.",
      47
    );
  }

  // ------------------------------------------------------------
  // 15. Verify M1 audit event
  // ------------------------------------------------------------
  const auditCount = cdb.audit_events.countDocuments({
    module: "M1",
    eventType: "customer-record-management",
    customerId: candidateId,
    operator: "candidate"
  });

  if (auditCount < 1) {
    fail(
      "No Module 1 audit event was found with module M1, eventType customer-record-management, customerId CUST-ASSESS-M1, and operator candidate.",
      48
    );
  }

  // ------------------------------------------------------------
  // 16. Final success
  // ------------------------------------------------------------
  const customerTotal = cdb.customers.countDocuments({});
  const orderTotal = cdb.orders.countDocuments({});

  print(
    "VALIDATION_SUCCEEDED: MongoDB is reachable; database customer360 " +
    "has collections " +
    requiredCollections.join(", ") +
    "; customer CUST-ASSESS-M1 is present exactly once with " +
    "loyaltyTier Gold and status inactive; customers validation " +
    "uses the required $jsonSchema rules with strict/error enforcement; " +
    "invalid status 'pending' was rejected successfully; " +
    auditCount +
    " matching audit event(s) found. Current counts: customers=" +
    customerTotal +
    ", orders=" +
    orderTotal +
    "."
  );

} catch (err) {
  fail(
    "MongoDB validation query failed: " +
    (err && err.message ? err.message : err),
    50
  );
}
' 2>&1)

MONGO_RC=$?

printf '%s\n' "$CHECK_OUTPUT"
exit $MONGO_RC
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
                    Message = "Module 1 validation passed on VM '$($vm.Name)' in RG '$rg'. $runOutput"
                } | ConvertTo-Json
            }
            else {
                $lastFailure = "Module 1 validation failed on VM '$($vm.Name)' in RG '$rg'. Run command output: $runOutput"
                $found = $false
            }
        }

        if ($found) {
            Push-OutputBinding `
                -Name Response `
                -Value ([HttpResponseContext]@{
                    StatusCode = [HttpStatusCode]::OK
                    Body = $message
                })
        }
        else {
            $message = @{
                Status  = "Failed"
                Message = $lastFailure
            } | ConvertTo-Json

            Push-OutputBinding `
                -Name Response `
                -Value ([HttpResponseContext]@{
                    StatusCode = [HttpStatusCode]::OK
                    Body = $message
                })

            Start-Sleep -Seconds 10
        }
    }
    catch {
        $lastFailure = "Error during Module 1 administration check. Attempt $count of 3. Error: $($_.Exception.Message)"

        $message = @{
            Status  = "Failed"
            Message = $lastFailure
        } | ConvertTo-Json

        Push-OutputBinding `
            -Name Response `
            -Value ([HttpResponseContext]@{
                StatusCode = [HttpStatusCode]::OK
                Body = $message
            })

        Start-Sleep -Seconds 10
    }

} while ($count -lt 3 -and -not $found)

# Post-loop: if every attempt failed, emit a final failure JSON
# so CloudLabs always sees a structured result.
if (-not $found) {
    $message = @{
        Status  = "Failed"
        Message = "Module 1 Administration not validated in RG '$rg' after 3 attempts. Last result: $lastFailure"
    } | ConvertTo-Json

    Push-OutputBinding `
        -Name Response `
        -Value ([HttpResponseContext]@{
            StatusCode = [HttpStatusCode]::OK
            Body = $message
        })
}