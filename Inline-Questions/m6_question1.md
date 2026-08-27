## MetaData
Question Type : Single Choice

## Question
Internal tools report that they cannot connect to the `customer360` MongoDB database. Your first diagnostic attempt using `mongosh --quiet --eval 'db.adminCommand({ ping: 1 })'` fails with a connection error. Before concluding that `mongod` is stopped, which category of checks should you perform first to rule out simpler problems like authentication failures, network issues, or corrupted data files?

## Options
Option 1 : Immediately restart MongoDB, as connection failures always indicate a stopped service.
Option 2 : Perform platform-level checks using Linux tools: service status, process list, port listening status, service logs, and disk/memory resources to isolate the root cause before making any changes.
Option 3 : Assume the database files are corrupted and begin the recovery process from backups.
Option 4 : Notify the system administrator immediately as database failures are outside your authority to diagnose.

## Answers
Option 2

## Correct Answer Feedback
Option 2 is correct. Professional troubleshooting requires diagnosis before action. Using Linux tools (systemctl, pgrep, ss, journalctl, df, free) allows you to gather evidence about whether mongod is actually running, whether the port is listening, whether resources are exhausted, and what recent events occurred. This evidence-based approach prevents unnecessary restarts and identifies the true root cause. Once diagnosed, you can apply the correct fix.

## Incorrect Answer Feedback
The selected option is not correct. Option 2 is the correct answer. Evidence-based troubleshooting is essential. Platform diagnostics provide factual information about service state, process existence, port status, and logs before taking any recovery actions.

## Number of Retries
1
