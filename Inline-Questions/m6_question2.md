## MetaData
Question Type : Single Choice

## Question
You run `systemctl status mongod` and observe: `Active: inactive (dead)` and `Enabled: no`. You also run `pgrep -a mongod` which returns no output, and `sudo ss --listen --tcp --process --numeric | grep 27017` shows no listening process on port 27017. Based on these diagnostic results, what is the most accurate conclusion about the MongoDB service state?

## Options
Option 1 : The service status command is lying and mongod must be running in the background despite the negative checks.

Option 2 : MongoDB is running but authentication is misconfigured, which is why the port check failed.

Option 3 : The mongod service is stopped (not running) and disabled (will not start automatically on reboot), which matches the reported symptom of unavailable database access.

Option 4 : MongoDB is partially running with some processes active but the main service is misconfigured.

## Answers
Option 3 : 1

## Correct Answer Feedback
Option 3 is correct.

## Number of Retries
1
