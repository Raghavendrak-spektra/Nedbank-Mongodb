## MetaData
Question Type : Single Choice

## Question
After recovering the stopped mongod service, you verify functionality by running: `mongosh --quiet --eval 'db.adminCommand({ ping: 1 })'` (succeeds), `db.customers.countDocuments()` (returns 5000), and `db.orders.countDocuments()` (returns 15000). These results prove that the customer360 database and collections are functional. Why is it important to verify collection document counts specifically, rather than just confirming the ping succeeds?

## Options
Option 1 : Document counts do not matter; the ping command is the only verification needed.

Option 2 : Document counts verify that not only is the service running, but the data files were not corrupted and the collections are intact and accessible, proving the database is truly operational for application use.

Option 3 : High document counts indicate that a performance optimization is needed because MongoDB is slow with large datasets.

Option 4 : Document counts are required by MongoDB licensing and must be reported to the vendor.

## Answers
Option 2 : 1

## Correct Answer Feedback
Option 2 is correct.

## Number of Retries
1
