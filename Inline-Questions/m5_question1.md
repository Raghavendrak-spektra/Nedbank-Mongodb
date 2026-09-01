## MetaData
Question Type : Single Choice

## Question
In the Secure MongoDB Access exercise, you need to create the `c360Admin` user in the `admin` database before turning on authorization in `/etc/mongod.conf`. Why is this order important?

## Options
Option 1 : MongoDB requires at least one administrative user before authorization is enabled; otherwise there may be no authenticated account available to manage users and roles.

Option 2 : The `customer360` database can only store application data after all reporting users are created.

Option 3 : Authorization automatically deletes existing users unless they were created in the `customer360` database first.

Option 4 : The `mongod` service cannot restart when any user exists in the `admin` database.

## Answers
Option 1 : 1

## Correct Answer Feedback
Option 1 is correct

## Number of Retries
1

