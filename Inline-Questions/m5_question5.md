## MetaData
Question Type : Single Choice

## Question
While testing `c360Reporter`, read queries against `customer360.customers` succeed, but an `insertOne()` operation and an admin command such as `usersInfo` are denied. What does this prove?

## Options
Option 1 : The reporter account has no valid permissions and must be recreated with the `root` role.

Option 2 : MongoDB is blocking all operations because the database service is offline.

Option 3 : Role-based access control is working as intended: the account can read allowed data but cannot write data or perform administrative actions.

Option 4 : The `customers` collection is locked and cannot be used by any account.

## Answers
Option 3 : 1

## Correct Answer Feedback
Option 3 is correct

## Number of Retries
1

