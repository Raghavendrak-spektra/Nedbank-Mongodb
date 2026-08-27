## MetaData
Question Type : Single Choice

## Question
A reusable analytics pipeline calculates completed-order revenue by region. It currently groups all orders, projects the metric fields, sorts the results, and then uses `$match` to keep only orders whose `status` is `Completed` and whose `orderDate` is within the reporting period. Which change most effectively reduces the amount of data processed by the later stages while preserving the intended metric?

## Options
Option 1 : Move `$project` after `$match` but keep both stages after `$group`
Option 2 : Add a second `$group` stage before `$match`
Option 3 : Move `$match` to the beginning of the pipeline, before `$group`
Option 4 : Move `$sort` to the beginning of the pipeline, before `$group`

## Answers
Option 3 : 1

## Correct Answer Feedback
Option 3 is correct answer, placing `$match` first filters out irrelevant orders before grouping, projection, and sorting, so later stages process fewer documents and the reusable report still calculates revenue only for the requested status and reporting period.

## Incorrect Answer Feedback
Selected Option is not correct Option 1 is the correct answer

## Number of Retries
1
