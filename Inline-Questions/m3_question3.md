## MetaData
Question Type : Single Choice

## Question
You created index `m3_completed_orders_idx` with key pattern `{ status: 1, orderDate: -1 }` on the `customer360.orders` collection. After running the same query with `explain("executionStats")`, you observe: `totalDocsExamined: 25`, `nReturned: 25`, `winningPlanStage: "FETCH"`, and `executionTimeMillis: 3` (compared to baseline `executionTimeMillis: 450`). What does the `FETCH` stage in the winning plan indicate about your index optimization?

## Options
Option 1 : The FETCH stage means MongoDB must still examine every document in the collection, so the index did not improve performance.
Option 2 : The FETCH stage indicates MongoDB used the index to identify matching documents efficiently, then fetched the complete documents from the collection, achieving the optimization goal.
Option 3 : The FETCH stage is a sign that the index is incomplete and you need to add more fields using index projection to avoid fetching documents.
Option 4 : The FETCH stage shows the query is still using a collection scan and the index is not being utilized at all.

## Answers
Option 2

## Correct Answer Feedback
Option 2 is correct. The FETCH stage indicates that MongoDB successfully used the index to narrow down which documents to retrieve (based on status and orderDate), and then fetched only those 25 matching documents. The dramatic reduction from 15,000 examined documents to 25, and the 150x speedup in execution time, confirms the index optimization is successful.

## Incorrect Answer Feedback
The selected option is not correct. Option 2 is the correct answer. The FETCH stage combined with totalDocsExamined matching nReturned is a positive indicator of an efficient query plan supported by your index.

## Number of Retries
1
