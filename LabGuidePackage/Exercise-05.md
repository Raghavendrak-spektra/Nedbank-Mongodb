# Exercise 05: Secure MongoDB Access

## Overview

In this exercise, you will configure MongoDB authentication and authorization for the `customer360` database. The security team requires that only authenticated users with appropriate least-privilege roles can access the database. You will create an administrative user, enable authorization, create a read-only reporting user, and verify that permissions are correctly enforced.

## Scenario 1: Administrative User Setup and Authorization Enablement

**Scenario:** MongoDB must be secured with authentication before being used in production. The first step is to create an administrative user with full privileges, then enable MongoDB authorization. Once authorization is enabled, all database access requires valid credentials.

You must create user `c360Admin` in the `admin` database with administrative privileges, enable authorization in `/etc/mongod.conf`, and restart the service. This initialization sequence is critical: if you enable authorization before creating an admin user, the database becomes inaccessible.

**Assessment Questions:**

Answer the following questions to assess your understanding of MongoDB security initialization:

<br>

<question source="https://raw.githubusercontent.com/Raghavendrak-spektra/Nedbank-Mongodb/refs/heads/main/Inline-Questions/m3_question2.md" />

<br>

<question source="https://raw.githubusercontent.com/Raghavendrak-spektra/Nedbank-Mongodb/refs/heads/main/Inline-Questions/m3_question2.md" />

<br>

---

## Scenario 2: Least-Privilege User Creation and Permission Testing

**Scenario:** After securing MongoDB with administrative authentication, the next step is to create application accounts with the minimum permissions needed for their function. The reporting application needs only read-only access to the `customer360` database.

You must create user `c360Reporter` with the `read` role on `customer360` (no write, admin, or other elevated permissions), then verify that: (1) read operations succeed, (2) write operations are denied, and (3) administrative operations are denied.

**Assessment Questions:**

Answer the following questions to assess your understanding of least-privilege user configuration and permission verification:

<br>

<question source="https://raw.githubusercontent.com/Raghavendrak-spektra/Nedbank-Mongodb/refs/heads/main/Inline-Questions/m3_question2.md" />

<br>

<question source="https://raw.githubusercontent.com/Raghavendrak-spektra/Nedbank-Mongodb/refs/heads/main/Inline-Questions/m3_question2.md" />

<br>

<question source="https://raw.githubusercontent.com/Raghavendrak-spektra/Nedbank-Mongodb/refs/heads/main/Inline-Questions/m3_question2.md" />

<br>

---

## Success Criteria

* `c360Admin` is created in the `admin` database with administrative privileges
* MongoDB authorization is enabled via `/etc/mongod.conf`
* `c360Reporter` is created with only the `read` role on `customer360`
* `c360Reporter` can successfully read data from `customer360`
* `c360Reporter` cannot insert or modify data
* `c360Reporter` cannot perform administrative operations
* MongoDB service restarts successfully with authorization enabled

## Summary

You created an administrative MongoDB account, enabled authorization, created a least-privilege reporting account with read-only access, and verified that the account can perform permitted read operations while being correctly denied write and administrative operations.
