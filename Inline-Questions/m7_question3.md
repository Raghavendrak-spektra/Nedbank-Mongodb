## MetaData
Question Type : Single Choice

## Question
The user `app_user` is verified to exist in the Database Access settings with authentication database `admin`. The application now authenticates successfully but fails when attempting to insert a document into `customer360.orders`: authorization error `user app_user is not authorized to perform: insert on customer360.orders`. The connection and authentication are working. Which Atlas configuration area must you review to fix this authorization failure?

## Options
Option 1 : The backup settings, because authorization failures indicate backup conflicts.

Option 2 : The Database Access settings in Atlas, where you must verify or modify the user's assigned database roles to grant write permissions on the `customer360` database and `orders` collection.

Option 3 : The IP Whitelist again, as authorization failures are always caused by network issues.

Option 4 : The password settings, because authorization and authentication are the same thing in MongoDB.

## Answers
Option 2 : 1

## Correct Answer Feedback
Option 2 is correct

## Number of Retries
1
