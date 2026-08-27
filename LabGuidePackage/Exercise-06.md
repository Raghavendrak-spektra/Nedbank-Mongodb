# Exercise 06: Troubleshoot a Stopped MongoDB Service

## Overview

In this exercise, you will investigate a MongoDB availability incident on the lab VM. Internal tools report that they cannot access the `customer360` database. Your task is to diagnose the root cause using Linux platform checks, recover the service, and document the incident for operational reference.

## Scenario 1: Incident Detection and Evidence Gathering

**Scenario:** The support queue reports that the customer360 application is unable to connect to MongoDB. A simple ping command `mongosh --quiet --eval 'db.adminCommand({ ping: 1 })'` fails with a connection error. You cannot determine from the error message alone whether the problem is a stopped service, an authentication issue, a network problem, or database corruption.

You must gather evidence using Linux platform checks: service status, process list, port listening status, service logs, and resource availability. Each check provides independent evidence that helps isolate the true cause without making assumptions.

**Assessment Questions:**

Answer the following questions to assess your understanding of systematic troubleshooting:

<br>

<question source="https://raw.githubusercontent.com/Raghavendrak-spektra/Nedbank-Mongodb/refs/heads/main/Inline-Questions/m6_question1.md" />

<br>

<question source="https://raw.githubusercontent.com/Raghavendrak-spektra/Nedbank-Mongodb/refs/heads/main/Inline-Questions/m6_question2.md" />

<br>

---

## Scenario 2: Service Recovery and Functional Verification

**Scenario:** Your diagnostic checks conclusively show that the mongod service is stopped and disabled. The injected incident condition is confirmed. You must now recover the service by enabling it and starting it, then verify that recovery is complete by confirming both service state and functional database access.

Recovery involves: (1) enabling the service so it starts automatically on reboot, (2) starting the service, (3) verifying that the service is active and processes are listening, and (4) confirming that the database is actually functional and accessible.

**Assessment Questions:**

Answer the following questions to assess your understanding of service recovery and validation:

<br>

<question source="https://raw.githubusercontent.com/Raghavendrak-spektra/Nedbank-Mongodb/refs/heads/main/Inline-Questions/m6_question3.md" />

<br>

<question source="https://raw.githubusercontent.com/Raghavendrak-spektra/Nedbank-Mongodb/refs/heads/main/Inline-Questions/m6_question4.md" />

<br>

<question source="https://raw.githubusercontent.com/Raghavendrak-spektra/Nedbank-Mongodb/refs/heads/main/Inline-Questions/m6_question5.md" />

<br>

---

## Success Criteria

* MongoDB service is diagnosed as stopped and disabled using multiple independent checks
* `mongod` service is enabled to start automatically on reboot
* `mongod` service is started and verified as active
* MongoDB responds to a ping command
* `customer360` database collections are accessible and contain expected data
* Incident documentation is saved with diagnosis, checks used, recovery action, and verification results

## Summary

You investigated a MongoDB availability incident using systematic Linux platform diagnostics, identified the stopped and disabled service condition, recovered the service by enabling and starting it, verified functional recovery through database access tests, and documented the incident for operational reference.
