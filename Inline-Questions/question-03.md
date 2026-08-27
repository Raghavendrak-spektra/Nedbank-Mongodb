## MetaData
Question Type : Single Choice

## Question
A query on `customer360.customers` uses the predicate `{ region: "West", status: "active" }` and sorts by `{ createdAt: -1 }`. Its baseline `explain("executionStats")` shows a `COLLSCAN`, an in-memory `SORT`, and many more documents examined than returned. Which index best supports both the equality predicates and the requested sort?

## Options
Option 1 : `{ createdAt: 1, region: 1, status: 1 }`
Option 2 : `{ region: 1, createdAt: 1, status: 1 }`
Option 3 : `{ status: 1 }`
Option 4 : `{ region: 1, status: 1, createdAt: -1 }`

## Answers
Option 4 : 1

## Correct Answer Feedback
Option 4 is correct answer, because the equality predicate fields form the index prefix and `createdAt: -1` follows them in the direction requested by the sort. This allows MongoDB to narrow the matching records and return them in index order, avoiding a full collection scan and in-memory sort for this query shape.

## Incorrect Answer Feedback
Selected Option is not correct Option 1 is the correct answer

## Number of Retries
1
