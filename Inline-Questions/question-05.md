## MetaData
Question Type : Single Choice

## Question
A reporting user must read data and run aggregation reports in the `customer360` database, but must not modify data or administer other databases. Testing shows the user can run `find()` successfully and can also insert a document into `customer360.orders`. Which role assignment violates least privilege, and what should replace it?

## Options
Option 1 : The `dbAdmin` role scoped to `customer360` violates least privilege; replace it with the `userAdmin` role scoped to `customer360`.
Option 2 : The `clusterMonitor` role violates least privilege; replace it with the `dbOwner` role scoped to `customer360`.
Option 3 : The `readWriteAnyDatabase` role violates least privilege; replace it with the `read` role scoped to `customer360`.
Option 4 : The `read` role scoped to `customer360` violates least privilege; replace it with the `readWrite` role scoped to `customer360`.

## Answers
Option 3 : 1

## Correct Answer Feedback
Option 3 is correct answer, because `readWriteAnyDatabase` grants unnecessary write access across databases, while `read` on `customer360` permits the required queries and aggregation reports without allowing inserts or administrative operations.

## Incorrect Answer Feedback
Selected Option is not correct Option 1 is the correct answer

## Number of Retries
1
