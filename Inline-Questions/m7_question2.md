## MetaData
Question Type : Single Choice

## Question
After adding the application's IP address to the IP Whitelist, the connection timeout error is resolved and the application establishes a TCP connection to the Atlas cluster. However, the application now fails with an authentication error: `Authentication failed for user app_user on database admin`. The connection string specifies username `app_user` and password correctly. What is the most likely cause of this authentication failure?

## Options
Option 1 : MongoDB Atlas requires all users to authenticate against the `admin` database, but the user may be created in a different database or may not exist in Atlas at all.

Option 2 : TLS encryption is interfering with the authentication process and must be disabled.

Option 3 : The password is definitely incorrect and needs to be reset immediately.

Option 4 : The connection string format is incompatible with Atlas security features.

## Answers
Option 1 : 1

## Correct Answer Feedback
Option 1 is correct.

## Number of Retries
1
