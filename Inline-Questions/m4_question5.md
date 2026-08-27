## MetaData
Question Type : Single Choice

## Question
You attempt to test a denied administrative operation using `c360Reporter`: `db.getSiblingDB("admin").runCommand({ usersInfo: 1 })`. MongoDB returns an authorization error instead of returning admin user information. Additionally, when you attempt an insert with `c360Reporter` (`db.orders.insertOne({ test: true })`), MongoDB also returns an authorization error. What do these two failed operations together demonstrate about the authorization implementation?

## Options
Option 1 : The failures prove that MongoDB is not actually using the `read` role and instead has some other undocumented access control mechanism.

Option 2 : Both operations failed because the `c360Reporter` account is not properly configured and should be deleted and recreated.

Option 3 : Both failures indicate that MongoDB's authorization system has a bug and cannot distinguish between different types of operations.

Option 4 : The authorization system is successfully enforcing role-based access control by denying operations outside the `read@customer360` scope: administrative operations (usersInfo on admin database) and write operations (insert on any collection).

## Answers
Option 4 : 1

## Correct Answer Feedback
Option 4 is correct.

## Number of Retries
1
