## MetaData
Question Type : Single Choice

## Question
Before enabling MongoDB authorization in the `customer360` database environment, you must create an administrative user. The `c360Admin` account needs to be created in the `admin` database with administrative privileges. Which of the following best explains why the administrative user must be created before authorization is enabled?

## Options
Option 1 : MongoDB requires all user accounts to exist before any security features are activated, regardless of their role or purpose.
Option 2 : Once authorization is enabled, only authenticated administrators can create new users. If no admin user exists beforehand, the database becomes inaccessible and unrecoverable.
Option 3 : Administrative users receive special encryption treatment that only works when they are created before authorization is enabled.
Option 4 : Creating users after authorization is enabled causes duplicate user entries in the system database and results in permission conflicts.

## Answers
Option 2

## Correct Answer Feedback
Option 2 is correct. Once MongoDB authorization is enabled, all database operations require authentication. If you enable authorization without first creating an administrative user, no one can authenticate to the database to create users or manage the system. This would lock out all access permanently. Therefore, the admin user must be created during the initialization phase before authorization is activated.

## Incorrect Answer Feedback
The selected option is not correct. Option 2 is the correct answer. Understanding the bootstrap sequence for MongoDB security is critical: create admin user first, then enable authorization. This ensures administrative access is always available for future user and permission management.

## Number of Retries
1
