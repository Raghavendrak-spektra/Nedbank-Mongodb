## MetaData
Question Type : Single Choice

## Question
After analyzing the query predicate `{ status: "completed", orderDate: { $gte: ISODate("2024-01-01T00:00:00Z") } }` and sort order `{ orderDate: -1 }`, you need to design an index to optimize this query. The query uses `status` as an equality filter and `orderDate` as a range filter with descending sort. Which index key pattern and direction would most effectively support this query according to ESR rule (Equality, Sort, Range)?

## Options
Option 1 : Create index `{ orderDate: 1 }` because the query only needs to optimize the sort operation.

Option 2 : Create index `{ orderDate: -1, status: 1 }` because the sort field should come first in the index.

Option 3 : Create index `{ status: 1, orderDate: -1 }` to support equality filter first, then sort descending on the range field.

Option 4 : Create index `{ status: 1, orderDate: 1 }` and MongoDB will automatically reverse the direction for descending sorts.

## Answers
Option 3 : 1

## Correct Answer Feedback
Option 3 is correct.

## Number of Retries
1
