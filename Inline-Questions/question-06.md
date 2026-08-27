## MetaData
Question Type : Single Choice

## Question
The `customer360` database is unavailable. Your checks show that `systemctl is-active mongod` returns `inactive`, `systemctl is-enabled mongod` returns `disabled`, no `mongod` process or TCP port 27017 listener exists, disk space is available, and the MongoDB log ends with a clean shutdown. What is the most likely cause and appropriate remediation?

## Options
Option 1 : The MongoDB service is stopped and disabled; run `sudo systemctl enable --now mongod`, then verify the service, port, and database query.
Option 2 : A network firewall is blocking MongoDB; open TCP port 27017 to the internet and leave the service state unchanged.
Option 3 : The disk is full and MongoDB data is corrupted; delete the database files and reseed the dataset.
Option 4 : Authentication is rejecting the connection; reset all MongoDB user passwords before checking the service state.

## Answers
Option 1

## Correct Answer Feedback
Option 1 is correct answer, the inactive and disabled service state, absent process and listener, available disk space, and clean shutdown indicate a stopped service rather than a network, storage, or authentication failure. Enabling and starting `mongod` addresses the cause, after which availability should be verified.

## Incorrect Answer Feedback
Selected Option is not correct Option 1 is the correct answer

## Number of Retries
1
