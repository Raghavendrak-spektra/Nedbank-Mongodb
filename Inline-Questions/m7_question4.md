## MetaData
Question Type : Single Choice

## Question
You review the current roles assigned to `app_user` in MongoDB Atlas Database Access and discover it has the `readWriteAnyDatabase` role. While this role does permit the insert operation that failed, it grants far more permissions than the application requires (which only needs to read and write to the `customer360` database). According to least-privilege principles, what should you do?

## Options
Option 1 : Leave the `readWriteAnyDatabase` role in place because changing roles is risky and might break the application.

Option 2 : Remove the `readWriteAnyDatabase` role and assign a more restrictive role, such as `readWrite` on only the `customer360` database, reducing the risk if the credentials are compromised or misused.

Option 3 : Add additional roles to make the account more secure through defense-in-depth.

Option 4 : Create a new user with even more permissions to serve as a backup account.

## Answers
Option 2 : 1

## Correct Answer Feedback
Option 2 is correct.

## Number of Retries
1
