## MetaData
Question Type : Single Choice

## Question
After analyzing the query predicate `{ status: "completed", orderDate: { $gte: ISODate("2024-01-01T00:00:00Z") } }` and sort order `{ orderDate: -1 }`, you need to design an index to optimize this query. The query uses `status` as an equality filter and `orderDate` as a range filter with descending sort. Which index key pattern and direction would most effectively support this query according to ESR rule (Equality, Sort, Range)?

## Options
Option 1 : Create index `{ orderDate: -1, status: 1 }` because the sort field should come first in the index.
Option 2 : Create index `{ status: 1, orderDate: -1 }` to support equality filter first, then sort descending on the range field.
Option 3 : Create index `{ orderDate: 1 }` because the query only needs to optimize the sort operation.
Option 4 : Create index `{ status: 1, orderDate: 1 }` and MongoDB will automatically reverse the direction for descending sorts.

## Answers
Option 2

## Correct Answer Feedback
Option 2 is correct. Following the ESR (Equality, Sort, Range) rule, the index should have: status first (equality predicate), then orderDate (which serves both as range filter and sort field). Descending direction on orderDate matches the query's descending sort requirement, allowing MongoDB to traverse the index in the correct order.

## Incorrect Answer Feedback
The selected option is not correct. Option 2 is the correct answer. The ESR rule guides optimal index design: Equality predicates first, then Sort fields matching the sort direction, then Range predicates (or combined range/sort in this case).

## Number of Retries
1
