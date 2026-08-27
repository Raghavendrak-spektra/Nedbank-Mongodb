# Exercise 07: MongoDB Atlas Operations

## Overview

In this exercise, you will investigate a MongoDB Atlas access incident where the `customer360` application cannot connect to or operate against an Atlas cluster. Your task is to diagnose the failure by checking network access, authentication, and authorization configurations, apply least-privilege principles to reduce unnecessary permissions, and verify that the application is fully operational.

## Scenario 1: Network and Authentication Access Troubleshooting

**Scenario:** The `customer360` application deployed on an Azure VM in East US attempts to connect to a MongoDB Atlas cluster using a connection string with the application user credentials. The connection fails with a network timeout error, suggesting the application cannot reach the Atlas cluster at all.

You must diagnose this at two levels: (1) network access—is the application's IP address whitelisted in Atlas Network Access settings? (2) authentication—does the user account exist in Atlas Database Access settings? Network access must be verified first, as it is the outermost layer of the security model.

**Assessment Questions:**

Answer the following questions to assess your understanding of MongoDB Atlas network and authentication access:

- [m7_question1.md](../Inline-Questions/m7_question1.md) - Diagnose network access failures using IP Whitelist
- [m7_question2.md](../Inline-Questions/m7_question2.md) - Distinguish network access from authentication failures

---

## Scenario 2: Authorization and Least-Privilege Configuration

**Scenario:** After resolving network and authentication issues, the application connects successfully but fails on data operations with authorization errors. The user account exists and authenticates, but lacks proper permissions on the `customer360` database.

Additionally, you discover the user account has been over-provisioned with the `readWriteAnyDatabase` role, which violates least-privilege principles. You must: (1) grant the correct permissions for the application to work, and (2) reduce permissions to the minimum necessary, significantly reducing the blast radius if credentials are compromised.

**Assessment Questions:**

Answer the following questions to assess your understanding of MongoDB Atlas authorization and least-privilege principles:

- [m7_question3.md](../Inline-Questions/m7_question3.md) - Diagnose authorization failures and fix permissions
- [m7_question4.md](../Inline-Questions/m7_question4.md) - Apply least-privilege principles to reduce unnecessary permissions
- [m7_question5.md](../Inline-Questions/m7_question5.md) - Verify comprehensive access control across all security layers

---

## Success Criteria

* Application's source IP address is whitelisted in MongoDB Atlas Network Access settings
* User account exists in Atlas Database Access with correct authentication database
* User account has appropriate role assignments for `customer360` database operations
* User permissions are reduced to least-privilege (e.g., `readWrite@customer360` instead of `readWriteAnyDatabase`)
* Application can successfully read from and write to `customer360` collections
* All three security layers are verified: network access, authentication, and authorization

## Summary

You investigated a MongoDB Atlas access incident by systematically checking network access, authentication, and authorization configurations. You applied least-privilege reasoning to minimize unnecessary permissions, verified that all three security layers function correctly, and ensured the `customer360` application is fully operational with appropriate access controls.
