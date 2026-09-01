## MetaData
Question Type : Single Choice

## Question
The `customer360` application attempts to connect to a MongoDB Atlas cluster using a connection string: `mongodb+srv://app_user:password@customer360.mongodb.net/customer360`. The connection fails with a network timeout error. The application is deployed on an Azure VM in the East US region, and the Atlas cluster is deployed in the same region. Which Atlas configuration area should you check first to diagnose this network-level access failure?

## Options
Option 1 : The MongoDB Atlas encryption settings to ensure TLS is disabled.

Option 2 : The database user passwords to ensure they are simple enough to avoid encoding issues.

Option 3 : The IP Whitelist (Network Access) settings in MongoDB Atlas to verify that the application's source IP address (or network CIDR range) is permitted to connect to the cluster.

Option 4 : The backup settings to confirm that automated backups are not blocking incoming connections.

## Answers
Option 3 : 1

## Correct Answer Feedback
Option 3 is correct

## Number of Retries
1
