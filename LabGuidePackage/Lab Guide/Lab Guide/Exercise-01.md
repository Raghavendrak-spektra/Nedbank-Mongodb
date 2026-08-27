# Scenario 01: Manage customer records

## Scenario

You are the junior database operator on duty for a retail customer support team. A new customer record must be added to the local MongoDB `customer360` database, the `customers` collection must reject malformed customer records, and an operational audit note must show what changed.

## Overview

In this exercise, you will inspect the seeded retail database, perform customer CRUD operations with `mongosh`, apply a collection validator, update loyalty and account status information, and write an audit event. This is an assessment-style task: use the required end state and the command hints to complete the work without relying on a full solution script.

## Objectives

- Task 1: Inspect the customer data model
- Task 2: Insert the required assessment customer
- Task 3: Enable validation on the `customers` collection
- Task 4: Update loyalty and status fields
- Task 5: Record an audit event and validate the result

## Task 1: Connect to the lab VM and inspect the customer data model

In this task, you will confirm local MongoDB database are ready.

1. In the VM terminal, confirm MongoDB is reachable.

   ```bash
   systemctl status mongod --no-pager
   mongosh --quiet --eval 'db.adminCommand({ ping: 1 })'
   ```

2. Inspect the `customer360` database, its collections, and representative documents.

   ```bash
   mongosh customer360
   ```

3. In `mongosh`, identify the collections, count records, and inspect one document from each primary collection. You should be able to answer:

   - How many documents are in `customers`?
   - How many documents are in `orders`?
   - Which fields represent customer identity, email, region, loyalty tier, account status, and consent?

> [!Tip]
> Useful `mongosh` methods for this task include `show collections`, `db.<collection>.countDocuments()`, and `db.<collection>.findOne()`.

## Task 2: Insert the required assessment customer

In this task, you will add one known customer record that can be checked later by the validator.

1. Insert exactly one customer with the following required values into `db.customers`.

   | Field | Required value |
   |---|---|
   | `customerId` | `CUST-ASSESS-M1` |
   | `firstName` | `Assessment` |
   | `lastName` | `Operator` |
   | `email` | `candidate.m1@contoso-retail.example` |
   | `region` | `West` |
   | `loyaltyTier` | `Silver` |
   | `status` | `active` |
   | `consent.marketing` | Boolean `true` |
   | `consent.supportContact` | Boolean `true` |
   | `createdAt` | A MongoDB `Date` value |

2. Include any additional fields you observed in the seeded customer documents only if they fit the existing data model.

3. Query the inserted customer by `customerId` and confirm that it appears once.

> [!Important]
> Use Boolean values for consent fields, not the strings `"true"` or `"false"`. The validation task later in this exercise is expected to reject incorrect data types.

## Task 3: Enable validation on the `customers` collection

In this task, you will add collection validation rules so future customer writes must include core retail profile fields.

1. Use the MongoDB `collMod` command against the `customers` collection.

2. Configure a JSON schema validator that requires at least the following fields:

   - `customerId`
   - `email`
   - `region`
   - `loyaltyTier`
   - `status`
   - `consent`

3. Constrain these values in your validator:

   - `email`, `region`, `loyaltyTier`, and `status` must be strings.
   - `status` must be one of `active` or `inactive`.
   - `consent.marketing` must be a Boolean.
   - `consent.supportContact` must be a Boolean.

4. Set the validation action to reject invalid writes and use a validation level appropriate for enforcing future inserts and updates.

5. Test the validation rules by inserting an invalid customer record below and confirm that MongoDB rejects the write.

   ```javascript
   db.customers.insertOne({
   |   customerId: "TEST-INVALID",
   |   email: "test@example.com",
   |   region: "West",
   |   loyaltyTier: "Silver",
   |   status: "pending",
   |   consent: {
   |     marketing: true,
   |     supportContact: true
   |   }
   | })
   ```

<question>


## Task 4: Update loyalty and status fields

In this task, you will perform an operational update for the assessment customer.

1. Update the customer with `customerId: "CUST-ASSESS-M1"` so the final values are:

   - `loyaltyTier`: `Gold`
   - `status`: `inactive`

2. Add or update a timestamp field such as `updatedAt` with the current date.

3. Query the same customer and verify the final values.

4. Attempt one safe negative test: try to insert or update a temporary record with an invalid `status` such as `pending` or a string consent value such as `"true"`. Confirm MongoDB rejects it, then do not leave the invalid record in the collection.

## Task 5: Record an audit event and validate the result

In this task, you will create operational evidence in the `audit_events` collection and run the Module 1 validation.

1. Insert one audit event into `db.audit_events` with these minimum values:

   | Field | Required value |
   |---|---|
   | `module` | `M1` |
   | `eventType` | `customer-record-management` |
   | `customerId` | `CUST-ASSESS-M1` |
   | `operator` | `candidate` |
   | `note` | A short note explaining the insert, validation, and status/tier update |
   | `createdAt` | A MongoDB `Date` value |

2. Verify the audit event exists.

3. Run your own final checks before validation:

   - `customer360` is reachable.
   - `customers`, `orders`, and `audit_events` exist.
   - `CUST-ASSESS-M1` exists exactly once.
   - The assessment customer has `loyaltyTier: "Gold"` and `status: "inactive"`.
   - The `customers` collection has a validator.
   - An `audit_events` record exists for `module: "M1"` and `customerId: "CUST-ASSESS-M1"`.

4. Run the CloudLabs validation step for this exercise.

<validation step="Validate M1"/>

5. If validation fails, review the message and re-check the exact required field names and values listed in this exercise.

## Summary

You inspected the seeded `customer360` database, inserted a known customer record, enabled schema validation for customer writes, updated loyalty and account status information, and recorded an operational audit event. These are the core administration tasks expected of a junior MongoDB operator managing customer data in a retail environment.
