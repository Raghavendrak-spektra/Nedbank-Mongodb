## MetaData
Question Type : Single Choice

## Question
After adding the application's IP address to the IP Whitelist, the connection timeout error is resolved and the application establishes a TCP connection to the Atlas cluster. However, the application now fails with an authentication error: `Authentication failed for user app_user on database admin`. The connection string specifies username `app_user` and password correctly. What is the most likely cause of this authentication failure?

## Options
Option 1 : The password is definitely incorrect and needs to be reset immediately.
Option 2 : MongoDB Atlas requires all users to authenticate against the `admin` database, but the user may be created in a different database or may not exist in Atlas at all.
Option 3 : TLS encryption is interfering with the authentication process and must be disabled.
Option 4 : The connection string format is incompatible with Atlas security features.

## Answers
Option 2

## Correct Answer Feedback
Option 2 is correct. Authentication failures in MongoDB Atlas typically occur because: (1) the user does not exist in the database, (2) the user was created in a different database than specified in the connection string, or (3) the user's authentication database does not match the connection string. In MongoDB, users are created in specific databases (usually `admin` for application users in Atlas). If the user `app_user` does not exist or was created in a different database, authentication will fail. You must verify in the Atlas UI → Database Access that the `app_user` exists and is correctly configured.

## Incorrect Answer Feedback
The selected option is not correct. Option 2 is the correct answer. Authentication errors in MongoDB Atlas are usually caused by user configuration issues in the Database Access settings, not password problems initially. Always verify user existence and database assignments first.

## Number of Retries
1
