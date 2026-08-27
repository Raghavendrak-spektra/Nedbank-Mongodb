## MetaData
Question Type : Single Choice

## Question
You attempt to test a denied administrative operation using `c360Reporter`: `db.getSiblingDB("admin").runCommand({ usersInfo: 1 })`. MongoDB returns an authorization error instead of returning admin user information. Additionally, when you attempt an insert with `c360Reporter` (`db.orders.insertOne({ test: true })`), MongoDB also returns an authorization error. What do these two failed operations together demonstrate about the authorization implementation?

## Options
Option 1 : Both operations failed because the `c360Reporter` account is not properly configured and should be deleted and recreated.

Option 2 : The authorization system is successfully enforcing role-based access control by denying operations outside the `read@customer360` scope: administrative operations (usersInfo on admin database) and write operations (insert on any collection).

Option 3 : Both failures indicate that MongoDB's authorization system has a bug and cannot distinguish between different types of operations.

Option 4 : The failures prove that MongoDB is not actually using the `read` role and instead has some other undocumented access control mechanism.

## Answers
Option 2 : 1

## Correct Answer Feedback
Option 2 is correct.

## Number of Retries
1
