## MetaData
Question Type : Single Choice

## Question
You must create a reporting user `c360Reporter` with the following requirements: authentication database `customer360`, role `read` on `customer360`, and no administrative roles. You run the MongoDB command to create the user with the `read` role on the `customer360` database. When you verify the user with `db.getSiblingDB("customer360").getUser("c360Reporter")`, why is it critical that this user has ONLY the `read@customer360` role and no additional roles like `readWrite`, `dbAdmin`, or `userAdmin`?

## Options
Option 1 : MongoDB policy forbids assigning multiple roles to a single user account for organizational reasons.

Option 2 : Additional roles would slow down authentication and reporting queries, reducing performance for all users.

Option 3 : Least-privilege principle requires that accounts have only the minimum permissions needed for their function, reducing risk if credentials are compromised or misused.

Option 4 : Multiple roles on a single user account confuses MongoDB's authorization engine and may cause unpredictable behavior.

## Answers
Option 3 : 1

## Correct Answer Feedback
Option 3 is correct.

## Number of Retries
1
