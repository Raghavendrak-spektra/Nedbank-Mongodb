## MetaData
Question Type : Single Choice

## Question
You need to ensure that your created index `m3_completed_orders_idx` is the only non-default index on the `customer360.orders` collection before validation. You ran `db.orders.getIndexes()` and discovered you created three experimental indexes during troubleshooting: `m3_test_v1`, `m3_test_v2`, and `m3_completed_orders_idx`. The assessment validation expects a clear, single index decision supported by query evidence. Which action should you take?

## Options
Option 1 : Keep the experimental indexes but rename them to follow the `m3_` naming convention so they appear intentional.

Option 2 : Drop all three indexes and create a new one with a different name to avoid confusion with failed experiments.

Option 3 : Leave all three indexes in place because they provide redundancy and may help with other queries.

Option 4 : Drop the experimental indexes `m3_test_v1` and `m3_test_v2`, keeping only `m3_completed_orders_idx` which you can justify from the query predicate and sort 
evidence.

## Answers
Option 4 : 1

## Correct Answer Feedback
Option 4 is correct.

## Number of Retries
1
