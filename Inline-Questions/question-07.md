## MetaData
Question Type : Single Choice

## Question
An Atlas cluster is shown as **Available**. The VM's current public egress IP is already in the Atlas IP access list. A scoped database user can connect and read documents from `customer360.customers`, but an insert into `customer360.audit_events` fails with `not authorized`. Which cause and fix best match this evidence?

## Options
Option 1 : The cluster is paused; resume the cluster and retry the insert.
Option 2 : The client IP is blocked; add `0.0.0.0/0` to the IP access list.
Option 3 : The database user lacks write permission on `customer360`; grant that user the `readWrite` role scoped to `customer360`, then reconnect with the correct authentication database and retest.
Option 4 : The authentication source is necessarily wrong; change `authSource` repeatedly without changing the user's role.

## Answers
Option 3

## Correct Answer Feedback
Option 3 is correct answer, successful connection and reads show that the available cluster, IP access list, and current authentication settings permit access. The authorization error on insert indicates that the database user lacks the required write privilege. Assigning `readWrite` only on `customer360` is the scoped fix; the retest should continue to use the authentication database where the Atlas user is defined.

## Incorrect Answer Feedback
Selected Option is not correct Option 3 is the correct answer

## Number of Retries
1
