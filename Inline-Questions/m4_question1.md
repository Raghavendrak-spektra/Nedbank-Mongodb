## MetaData
Question Type : Single Choice

## Question
Before enabling MongoDB authorization in the `customer360` database environment, you must create an administrative user. The `c360Admin` account needs to be created in the `admin` database with administrative privileges. Which of the following best explains why the administrative user must be created before authorization is enabled?

## Options
Option 1 : Creating users after authorization is enabled causes duplicate user entries in the system database and results in permission conflicts.

Option 2 : Once authorization is enabled, only authenticated administrators can create new users. If no admin user exists beforehand, the database becomes inaccessible and unrecoverable.

Option 3 : Administrative users receive special encryption treatment that only works when they are created before authorization is enabled.

Option 4 : MongoDB requires all user accounts to exist before any security features are activated, regardless of their role or purpose.

## Answers
Option 2 : 1

## Correct Answer Feedback
Option 2 is correct.

## Number of Retries
1
