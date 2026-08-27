## MetaData
Question Type : Single Choice

## Question
You have successfully created the administrative user `c360Admin` in the `admin` database and enabled MongoDB authorization by setting `security.authorization: enabled` in `/etc/mongod.conf`. You restart MongoDB and confirm the service is active. However, when you attempt to connect without credentials using `mongosh`, you receive a connection error. What does this error indicate about the authorization system?

## Options
Option 1 : MongoDB authorization has failed to enable properly because you should still be able to connect as a test.
Option 2 : Authorization is working correctly; the connection error is expected because MongoDB now requires authentication for all operations, including connection attempts.
Option 3 : The error indicates that MongoDB has become corrupted and you need to revert your configuration changes.
Option 4 : You need to disable authorization again because connection errors mean the feature is not compatible with your environment.

## Answers
Option 2

## Correct Answer Feedback
Option 2 is correct. Once authorization is enabled, MongoDB denies all connections and operations unless valid credentials are provided. This is the intended behavior—a connection error without credentials is proof that authorization is working as designed. You must now authenticate using the `c360Admin` account with the `-u`, `-p`, and `--authenticationDatabase` flags to access the database.

## Incorrect Answer Feedback
The selected option is not correct. Option 2 is the correct answer. Connection errors after enabling authorization are expected and indicate proper security functionality. Authentication is now required for all access.

## Number of Retries
1
