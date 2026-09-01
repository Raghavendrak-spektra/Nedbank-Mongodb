## MetaData
Question Type : Single Choice

## Question
Internal tools report that they cannot connect to the `customer360` MongoDB database. Your first diagnostic attempt using `mongosh --quiet --eval 'db.adminCommand({ ping: 1 })'` fails with a connection error. Before concluding that `mongod` is stopped, which category of checks should you perform first to rule out simpler problems like authentication failures, network issues, or corrupted data files?

## Options
Option 1 : Assume the database files are corrupted and begin the recovery process from backups.

Option 2 : Notify the system administrator immediately as database failures are outside your authority to diagnose.

Option 3 : Perform platform-level checks using Linux tools: service status, process list, port listening status, service logs, and disk/memory resources to isolate the root cause before making any changes.

Option 4 : Immediately restart MongoDB, as connection failures always indicate a stopped service.

## Answers
Option 3 : 1

## Correct Answer Feedback
Option 3 is correct

## Number of Retries
1
