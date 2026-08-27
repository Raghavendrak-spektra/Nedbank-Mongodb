## MetaData

Question Type : Single Choice

## Question

The `customer360` application cannot connect to its MongoDB Atlas cluster. The cluster is shown as running, but the application is connecting from a new public IP address. What should you investigate first?

## Options

Option 1 : The aggregation pipeline

Option 2 : The Atlas Network Access IP Access List

Option 3 : The customer document schema

Option 4 : The `customers` collection indexes

## Answers

Option 2

## Correct Answer Feedback

Option 2 is correct, because Atlas Network Access controls which client IP addresses are allowed to connect to the cluster. A new client IP that is not permitted can cause the connection to fail even when the cluster is running.

## Incorrect Answer Feedback

Selected Option is not correct. Option 2 is the correct answer because the scenario points to a network access restriction.

## Number of Retries

1
