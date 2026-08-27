## MetaData
Question Type : Single Choice

## Question
Based on your diagnosis that mongod is stopped and disabled, you now execute recovery actions: `sudo systemctl enable mongod` and `sudo systemctl start mongod`. You then verify: `systemctl is-active mongod` returns `active`, and `systemctl is-enabled mongod` returns `enabled`. What do these results prove about the recovery?

## Options
Option 1 : The service is now in the correct state for immediate operation, and the incident is fully recovered.
Option 2 : The systemctl commands succeeded in changing the service state, but you must still verify that MongoDB is actually accepting connections and the database is functional before declaring the incident resolved.
Option 3 : Recovery is complete because the service status changed, and no further testing is needed.
Option 4 : The enabled state means MongoDB will start automatically after reboot, so the incident is prevented from recurring in the future.

## Answers
Option 2

## Correct Answer Feedback
Option 2 is correct. While changing the service state from inactive/disabled to active/enabled is necessary, it is not sufficient to prove full recovery. You must verify functional recovery by: (1) confirming the MongoDB ping succeeds, (2) verifying that the customer360 database and collections are readable, and (3) confirming that the port is listening and the process exists. Only when all functional tests pass can you declare the incident fully resolved.

## Incorrect Answer Feedback
The selected option is not correct. Option 2 is the correct answer. Service state changes are a necessary but not sufficient condition for recovery. Functional verification is the final step that confirms the database is truly available to applications.

## Number of Retries
1
