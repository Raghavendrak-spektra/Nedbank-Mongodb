# Scenario 02: Protect the customer dataset with selective recovery

## Scenario

A support operations analyst reports that a small set of customer records was accidentally removed during routine maintenance. As the junior database operator, you must prove that the local `customer360` MongoDB database can be backed up and that only the missing customer records can be restored without replacing unrelated live changes made after the backup.

## Overview

In this assessment exercise, you will create a reusable backup script, run a timestamped database dump, record the IDs for a defined customer subset, add a live post-backup marker, delete only the recorded subset, and restore only those missing customer records from the backup into the live database. Do not use a full `--drop` restore for this scenario. Your evidence must show that the subset returned and that the post-backup marker was preserved.

## Objectives

- Task 1: Capture baseline counts
- Task 2: Create and run a reusable backup script
- Task 3: Record the recovery subset and a live post-backup marker
- Task 4: Delete only the recorded customer subset
- Task 5: Restore only missing customer records from backup
- Task 6: Verify recovery evidence and validate the end state

## Task 1: Capture baseline counts

In this task, you will access the Ubuntu terminal on your left and capture the starting counts used to assess recovery.

1. In the VM terminal, confirm that MongoDB is reachable.

   ```bash
   systemctl is-active mongod
   mongosh --quiet --eval 'db.adminCommand({ ping: 1 })'
   ```

2. Create the evidence directory if it is not already present in the user directory.

6. Capture current `customer360` collection counts before taking the backup.

   ```bash
   mongosh customer360 --quiet --eval '
   const counts = {
   capturedAt: new Date().toISOString(),
   customers: db.customers.countDocuments(),
   orders: db.orders.countDocuments(),
   audit_events: db.audit_events.countDocuments()
   };
   print(EJSON.stringify(counts, null, 2));
   ' | sudo tee mongodb-customer-data/evidence/m2-pre-backup-counts.json
   ```

> [!Important]
> Your recovery target is selective recovery, not disaster recovery. Preserve live changes made after the backup.

## Task 2: Create and run a reusable backup script

In this task, you will create a repeatable backup process that stores a timestamped dump under the required lab backup path.
1. Create the `scripts` directory inside `mongodb-customer-data`
   ```bash
   mkdir mongodb-customer-data/scripts
   ```

1. Move to the scripts directory:

   ```bash
   cd mongodb-customer-data/scripts
   ```

2. Create a reusable script named `m2-backup-customer360.sh`.

   ```bash
   sudo vim m2-backup-customer360.sh
   ```

3. **Write the script yourself.** The script must meet the following requirements:

   - Uses Bash strict mode.
   - Creates a timestamped folder under `mongodb-customer-data/backups/`.
   - Runs `mongodump` for the `customer360` database.
   - Prints the backup directory it created.

   command hint:

   ```bash
   mongodump --db customer360 --out "${BACKUP_DIR}"
   ```

4. Save the file, exit the editor, and make the script executable.

   ```bash
   sudo chmod +x m2-backup-customer360.sh
   ```

5. Run the backup script and capture its output as evidence.

   ```bash
   ./m2-backup-customer360.sh \
      | sudo tee ../evidence/m2-backup-run.txt
   ```

6. Confirm that the latest dump includes the `customers` and `orders` BSON files.

   ```bash
   find ../backups -path '*customer360*' -name '*.bson' | sort | tail
   ```

## Task 3: Record the recovery subset and a live post-backup marker (simulating data loss)

In this task, you will identify the exact customer records you will delete and create a live marker after the backup. The marker proves that your recovery method did not replace the live database with the backup copy.

1. Record the IDs for a small, controlled subset of inactive customers. Use the evidence file name shown here so the assessment can inspect your work.

   ```bash
   mongosh customer360 --quiet --eval '
   const ids = db.customers
     .find({ status: "inactive" }, { _id: 1 })
     .sort({ _id: 1 })
     .limit(10)
     .toArray()
     .map(d => d._id);
   print(EJSON.stringify({
     capturedAt: new Date().toISOString(),
     subsetName: "m2_inactive_customer_recovery_subset",
     subsetCount: ids.length,
     ids: ids
   }, null, 2));
   ' | sudo tee /opt/cloudlabs/mongodb-customer-data/evidence/m2-subset-ids.json
   ```

2. Inspect the subset evidence. You should have at least one ID and no more than 10 IDs.

   ```bash
   cat /opt/cloudlabs/mongodb-customer-data/evidence/m2-subset-ids.json
   ```

3. Insert a post-backup live marker into `audit_events`. Do not put the marker in the backup folder; it must exist only in the live database after the backup.

   ```bash
   mongosh customer360 --quiet --eval '
   db.audit_events.insertOne({
     eventType: "m2_post_backup_marker",
     module: "M2",
     note: "Live marker inserted after backup and before selective restore",
     createdAt: new Date()
   });
   printjson(db.audit_events.findOne({ eventType: "m2_post_backup_marker" }, { _id: 1, eventType: 1, createdAt: 1 }));
   ' | sudo tee /opt/cloudlabs/mongodb-customer-data/evidence/m2-post-backup-marker.json
   ```

<question>

> [!Note]
> A full `mongorestore --drop` would remove this marker unless it existed in the backup. That is why this exercise requires selective record recovery.

## Task 4: Delete only the recorded customer subset (simulating data loss)

In this task, you will simulate a small accidental deletion using only the IDs recorded in Task 3.

1. Delete only the customers whose IDs are listed in `/opt/cloudlabs/mongodb-customer-data/evidence/m2-subset-ids.json`.

   ```bash
      EVIDENCE=$(cat mongodb-customer-data/evidence/m2-subset-ids.json)

      mongosh customer360 --quiet --eval "
      const evidence = EJSON.parse(\`$EVIDENCE\`);
      const ids = evidence.ids || [];

      const result = db.customers.deleteMany({
      _id: { \$in: ids }
      });

      print(EJSON.stringify({
      deletedAt: new Date().toISOString(),
      attemptedIds: ids.length,
      deletedCount: result.deletedCount,
      deletedIds: ids
      }, null, 2));
      " | sudo tee mongodb-customer-data/evidence/m2-simulated-loss.json
   ```

2. Confirm that the subset is currently missing and that the post-backup marker still exists.

   ```bash
      export M2_EVIDENCE="$(cat mongodb-customer-data/evidence/m2-subset-ids.json)"

      mongosh customer360 --quiet --eval '
      const evidence = EJSON.parse(process.env.M2_EVIDENCE);
      const ids = evidence.ids || [];

      print(EJSON.stringify({
      remainingSubsetMatches: db.customers.countDocuments({ _id: { $in: ids } }),
      markerStillPresent: !!db.audit_events.findOne({ eventType: "m2_post_backup_marker" }),
      customersAfterLoss: db.customers.countDocuments(),
      ordersAfterLoss: db.orders.countDocuments()
      }, null, 2));
      '
   ```

> [!Important]
> Do not delete `orders`, do not drop the `customer360` database, and do not run `mongorestore --drop` for this module.

## Task 5: Restore only missing customer records from backup

Use the backup you created earlier to recover the customer records that were deleted during the simulated data loss.

1. Identify the most recent `customer360` backup created during this exercise.

2. Recover the `customers` collection into a **temporary recovery database** named `customer360_recovery`. Do not restore directly over the live `customer360` database.

3. Using the customer IDs recorded before the simulated deletion, restore **only those missing customer records** to the live `customer360.customers` collection.

4. Do not overwrite or replace any existing live customer records. The post-backup marker in `customer360.audit_events` must remain intact.

5. Record evidence showing:
   - The number of customer IDs requested for recovery.
   - The number of matching documents found in the backup.
   - The number of records restored.
   - That the recovered subset is present in the live database.
   - That the post-backup marker is still present.
   - That the `orders` collection was not affected.

6. Keep the temporary recovery database available until the recovery has been validated.

> **Congratulations** on completing the task! Now, it's time to validate it. Here are the steps:
> - Hit the Validate button for the corresponding task. If you receive a success message, you can proceed to the next task.
> - If not, carefully read the error message and retry the step, following the instructions in the lab guide.
> - If you need any assistance, please contact us at labs-support@spektrasystems.com. We are available 24/7 to help you out.

   <validation step="6ceac6de-b182-4fd9-b692-15eb7f2aa328" />


## Summary

You created a repeatable backup, recorded a specific customer subset, inserted a live post-backup marker, deleted only the recorded subset, restored only the missing customer records from the backup through a temporary recovery database, and verified that the marker was preserved. This is the preferred response for a small accidental deletion because it avoids overwriting unrelated live changes.
