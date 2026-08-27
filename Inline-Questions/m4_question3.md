## MetaData
Question Type : Single Choice

## Question
You must create a reporting user `c360Reporter` with the following requirements: authentication database `customer360`, role `read` on `customer360`, and no administrative roles. You run the MongoDB command to create the user with the `read` role on the `customer360` database. When you verify the user with `db.getSiblingDB("customer360").getUser("c360Reporter")`, why is it critical that this user has ONLY the `read@customer360` role and no additional roles like `readWrite`, `dbAdmin`, or `userAdmin`?

## Options
Option 1 : Additional roles would slow down authentication and reporting queries, reducing performance for all users.
Option 2 : Multiple roles on a single user account confuses MongoDB's authorization engine and may cause unpredictable behavior.
Option 3 : Least-privilege principle requires that accounts have only the minimum permissions needed for their function, reducing risk if credentials are compromised or misused.
Option 4 : MongoDB policy forbids assigning multiple roles to a single user account for organizational reasons.

## Answers
Option 3

## Correct Answer Feedback
Option 3 is correct. Least-privilege is a foundational security principle: grant only the minimum permissions necessary for a user to perform their function. A reporting user needs only to read data, not modify it or perform administrative tasks. If the `c360Reporter` account credentials were compromised, an attacker would be limited to read operations, not capable of deleting data, creating users, or damaging the system. This principle significantly reduces the blast radius of potential security incidents.

## Incorrect Answer Feedback
The selected option is not correct. Option 3 is the correct answer. Least-privilege access control is essential to information security. It limits the damage potential when credentials are compromised and prevents accidental misuse of administrative functions by accounts that don't need them.

## Number of Retries
1
