## MetaData
Question Type : Single Choice

## Question
The `customer360` application attempts to connect to a MongoDB Atlas cluster using a connection string: `mongodb+srv://app_user:password@customer360.mongodb.net/customer360`. The connection fails with a network timeout error. The application is deployed on an Azure VM in the East US region, and the Atlas cluster is deployed in the same region. Which Atlas configuration area should you check first to diagnose this network-level access failure?

## Options
Option 1 : The MongoDB Atlas encryption settings to ensure TLS is disabled.
Option 2 : The IP Whitelist (Network Access) settings in MongoDB Atlas to verify that the application's source IP address (or network CIDR range) is permitted to connect to the cluster.
Option 3 : The database user passwords to ensure they are simple enough to avoid encoding issues.
Option 4 : The backup settings to confirm that automated backups are not blocking incoming connections.

## Answers
Option 2

## Correct Answer Feedback
Option 2 is correct. Network timeouts when connecting to MongoDB Atlas typically indicate that the source IP address is not whitelisted in the IP Whitelist (Network Access) settings. MongoDB Atlas enforces strict network access control; only explicitly whitelisted IP addresses or CIDR ranges can establish connections. This is the first place to check for connection failures. The Atlas Security section → Network Access → IP Whitelist is where you add the application's IP address or network range.

## Incorrect Answer Feedback
The selected option is not correct. Option 2 is the correct answer. Network access control is the first layer of security in MongoDB Atlas. IP whitelisting must be configured before any application can connect, regardless of authentication credentials or encryption settings.

## Number of Retries
1
