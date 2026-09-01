## MetaData
Question Type : Single Choice

## Question
Based on your diagnosis that mongod is stopped and disabled, you now execute recovery actions: `sudo systemctl enable mongod` and `sudo systemctl start mongod`. You then verify: `systemctl is-active mongod` returns `active`, and `systemctl is-enabled mongod` returns `enabled`. What do these results prove about the recovery?

## Options
Option 1 : The systemctl commands succeeded in changing the service state, but you must still verify that MongoDB is actually accepting connections and the database is functional before declaring the incident resolved.

Option 2 : Recovery is complete because the service status changed, and no further testing is needed.

Option 3 : The enabled state means MongoDB will start automatically after reboot, so the incident is prevented from recurring in the future.

Option 4 : The service is now in the correct state for immediate operation, and the incident is fully recovered.

## Answers
Option 1 : 1

## Correct Answer Feedback
Option 1 is correct

## Number of Retries
1
