# Exercise 04: Build an operational support triage report

## Scenario

The retail support operations team needs a concise MongoDB report for daily support triage. This is not a generic revenue or business analytics exercise. Your report must help support leads identify operational risk signals, such as completed, cancelled, and returned orders, recent order volume, and exception volume in the `customer360` dataset.

## Overview

In this exercise, you will create one reusable `mongosh` aggregation script. The script must use `$match`, `$group`, `$project`, and `$sort`, return non-empty operational-support rows, and save local evidence that support or operations staff could use during triage.

The report is based only on fields that are present in the seeded `customer360.orders` collection.

## Objectives

- Task 1: Inspect operational support fields

- Task 2: Create a reusable triage aggregation script

- Task 3: Run the report and prove the output is non-empty

- Task 4: Validate the operational support report

## Task 1: Inspect operational support fields

In this task, you will confirm which fields in the seeded order data can support an operations triage report.

1. In the terminal on your left, confirm MongoDB is reachable:

   ```bash
   mongosh --quiet --eval 'db.adminCommand({ ping: 1 })'
   ```

2. Inspect the available order fields

3. Confirm the available status values

4. Confirm the available order channels

5. Review the seeded data and identify the fields that can be used for operational triage.

   The report will use:

   - `status` — identifies order state and operational exceptions.
   - `orderDate` — identifies recent orders and recent exception volume.
   - `channel` — provides an operational dimension for comparing exception volume.
   - `amount` — provides the monetary value associated with exception orders.

6. Use this operational-support report objective:

   **recent exception volume by order channel and status**

7. Confirm that the report will include triage-focused fields such as:

   - `orderCount`
   - `exceptionCount`
   - `exceptionAmount`
   - `latestExceptionDate`
   - `triagePriority`

   These fields help support leads determine which order channels and exception types require investigation first.

## Task 2: Create a reusable triage aggregation script

In this task, you will create the required aggregation script under the lab workspace. The aggregation must keep all four required stages: `$match`, `$group`, `$project`, and `$sort`.

The goal is to transform the order data into a concise report that support or operations staff can use to identify areas requiring attention. Use the fields you discovered during Task 1 and the reporting objective to decide which records should be included, how they should be grouped, which metrics should be calculated, and how the final results should be ordered.

1. Create `mongodb-customer-data/scripts/analytics-report.mongodb.js`.

1. Build the aggregation based on the order fields available in your lab dataset and the operational-support reporting objective from Task 1.
  
    **Your script should:**

    - Connect to the customer360 database.
    - Read data from the appropriate order collection.
    - Select records relevant to operational support using $match.
    - Group the records using dimensions that help support teams compare operational activity.
    - Calculate useful operational metrics from the available data.
    - Use $project to produce a concise, readable report.
    - Use $sort to prioritize or organize the resulting rows.
    - Print the resulting report to the terminal.
    - Fail clearly if the aggregation produces no rows.

2. Confirm the script exists:

   ```bash
   ls -l /mongodb-customer-data/scripts/analytics-report.mongodb.js
   ```

3. Confirm that the script contains all four required aggregation stages:

   ```bash
   grep -E '\$match|\$group|\$project|\$sort' \
    mongodb-customer-data/scripts/analytics-report.mongodb.js
   ```

> **Note:** `$match` appears before `$group` so only recent cancelled and returned orders are passed to the grouping stage. This keeps the aggregation focused on operational exceptions rather than grouping every order.

## Task 3: Run the report and prove the output is non-empty

In this task, you will run the report and preserve evidence for operations review.

1. Run the operational support triage script:

   ```bash
   mongosh --quiet \
   mongodb-customer-data/scripts/analytics-report.mongodb.js
   ```

2. Verify that the output contains operational triage rows.

3. Confirm that the output contains fields such as:

   - `channel`
   - `status`
   - `orderCount`
   - `exceptionCount`
   - `exceptionAmount`
   - `latestExceptionDate`
   - `triagePriority`

4. Save a successful run to the evidence folder:

   ```bash
   mongosh --quiet \
   mongodb-customer-data/scripts/analytics-report.mongodb.js \
   | sudo tee mongodb-customer-data/evidence/m4-analytics-output.txt
   ```

6. Confirm that the expected operational fields are present:

   ```bash
   grep -E 'channel|status|orderCount|exceptionCount|exceptionAmount|triagePriority' \
   mongodb-customer-data/evidence/m4-analytics-output.txt
   ```

> [!Important]
> The evidence should contain operational metric names, counts, amounts, dates, and triage priorities only.

5. Run the CloudLabs validation step for this exercise.

   `<validation step="Validate M4">`

6. If validation fails, verify that:

   - `mongodb-customer-data/scripts/analytics-report.mongodb.js` exists.
   - The script contains `$match`, `$group`, `$project`, and `$sort`.
   - The script executes without MongoDB errors.
   - The report produces at least one result.
   - The evidence file exists and is non-empty.
   - The evidence contains `exceptionCount`, `exceptionAmount`, and `triagePriority`.
   - The aggregation uses actual fields from the seeded `orders` collection.

## Summary

You created a reusable MongoDB aggregation report for support and operations triage. The report uses `$match` to identify recent cancelled and returned orders, `$group` to summarize exception volume by channel and status, `$project` to shape operational triage metrics, and `$sort` to prioritize the resulting rows.

You also executed the report successfully and saved non-empty evidence for operational review.
