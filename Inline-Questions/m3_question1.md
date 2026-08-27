## MetaData
Question Type : Single Choice

## Question
A support dashboard query retrieves recent completed orders from the `customer360.orders` collection, filtering by `status: "completed"` and `orderDate: { $gte: ISODate("2024-01-01T00:00:00Z") }`, sorted by `orderDate` descending, with a limit of 25 results. The baseline `explain("executionStats")` shows `totalDocsExamined: 15000` but `nReturned: 25`. Which analysis best explains this performance characteristic and indicates the need for an index?

## Options
Option 1 : The query is efficient because it examines only 600 times more documents than it returns, which is acceptable for large collections without indexes.
Option 2 : The high ratio of examined documents to returned documents indicates the query is scanning a collection without an efficient index supporting the filter and sort predicates.
Option 3 : The query performance is optimal because MongoDB is using the default _id index to sort results in descending order.
Option 4 : The large number of examined documents is expected because the query must read all documents before applying the sort operation.

## Answers
Option 2

## Correct Answer Feedback
Option 2 is correct. A ratio of 15,000 documents examined to retrieve 25 documents indicates an inefficient collection scan. A properly designed index on the filter fields (status, orderDate) and sort field would dramatically reduce the number of examined documents, improving query performance significantly.

## Incorrect Answer Feedback
The selected option is not correct. Option 2 is the correct answer. The high examined-to-returned ratio is a key performance indicator that an index is needed to support this query pattern.

## Number of Retries
1
