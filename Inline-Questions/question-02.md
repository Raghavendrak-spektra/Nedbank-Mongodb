## MetaData
Question Type : Single Choice

## Question
A backup of `customer360.customers` was created at 10:00. At 10:20, an operator accidentally deleted 12 known customer records. Other valid customer updates and a new post-backup marker record were added between 10:00 and 10:20. Which recovery approach is safest?

## Options
Option 1 : Restore the entire `customers` collection from the 10:00 backup with `--drop`, then recreate any newer changes that users report missing.
Option 2 : Restore the 10:00 backup into a temporary collection, select the 12 deleted records by their captured IDs, insert only records still missing from the live collection, and verify that the post-backup marker remains.
Option 3 : Delete the live `customer360` database and restore the complete backup so that all collections share the same backup timestamp.
Option 4 : Import every document from the backup directly into the live collection without filtering, allowing duplicate-key errors to identify records that do not need recovery.

## Answers
Option 2

## Correct Answer Feedback
Option 2 is correct answer, because the loss is limited to a known set of records. Staging the backup and restoring only IDs that are still missing minimizes changes to live data and preserves valid updates and records created after the backup; confirming the marker remains proves those newer changes were not overwritten.

## Incorrect Answer Feedback
Selected Option is not correct Option 2 is the correct answer

## Number of Retries
1
