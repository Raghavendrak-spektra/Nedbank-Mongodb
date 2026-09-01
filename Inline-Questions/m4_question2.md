## MetaData
Question Type : Single Choice

## Question
You have successfully created the administrative user `c360Admin` in the `admin` database and enabled MongoDB authorization by setting `security.authorization: enabled` in `/etc/mongod.conf`. You restart MongoDB and confirm the service is active. However, when you attempt to connect without credentials using `mongosh`, you receive a connection error. What does this error indicate about the authorization system?

## Options
Option 1 : You need to disable authorization again because connection errors mean the feature is not compatible with your environment.

Option 2 : Authorization is working correctly; the connection error is expected because MongoDB now requires authentication for all operations, including connection attempts.

Option 3 : The error indicates that MongoDB has become corrupted and you need to revert your configuration changes.

Option 4 : MongoDB authorization has failed to enable properly because you should still be able to connect as a test.

## Answers
Option 2 : 1

## Correct Answer Feedback
Option 2 is correct

## Number of Retries
1
