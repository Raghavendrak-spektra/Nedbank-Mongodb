## MetaData
Question Type : Single Choice

## Question
You are testing the `c360Reporter` account to verify that it can read data from the `customer360` database. You run the command: `db.customers.find({}, { _id: 0, email: 1, region: 1 }).limit(3).toArray()` and customer records are returned successfully. This test proves which security requirement has been successfully implemented?

## Options
Option 1 : It proves that the `c360Reporter` password is stored in an unencrypted format because the query executed immediately.

Option 2 : It proves that MongoDB authorization is completely disabled on the system and no security measures are in place.

Option 3 : It proves that the `c360Reporter` account can now perform any operation on any database without restrictions.

Option 4 : It proves that the `read` role on `customer360` correctly grants permission for SELECT/read operations on the `customers` collection.

## Answers
Option 4 : 1

## Correct Answer Feedback
Option 4 is correct.

## Number of Retries
1
