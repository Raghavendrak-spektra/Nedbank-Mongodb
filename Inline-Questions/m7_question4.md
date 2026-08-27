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
Option 2

## Correct Answer Feedback
Option 2 is correct. Least-privilege is a core security principle: grant only the minimum permissions necessary. The application needs to read and write on `customer360` only, not access any database. The `readWriteAnyDatabase` role is unnecessarily broad and violates least-privilege. Reducing it to `readWrite@customer360` significantly reduces the blast radius if the credentials are compromised—an attacker would be limited to the one database, not all databases. This is the correct security hardening step.

## Incorrect Answer Feedback
The selected option is not correct. Option 2 is the correct answer. Applying least-privilege principles to database accounts is not risky; it is a security best practice. Over-permissioned accounts represent a security vulnerability, not a safety feature. Adjust the role to match the application's actual requirements.

## Number of Retries
1
