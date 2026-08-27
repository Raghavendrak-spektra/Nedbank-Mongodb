# Exercise 03: Performance Tuning & Optimization

## Overview

In this exercise, you will investigate query performance issues in the MongoDB `customer360` database. A support dashboard query is running slowly when retrieving recent completed orders. Your task is to analyze the query execution plan, diagnose the performance bottleneck using evidence, design an appropriate index to optimize the query, and verify the improvement.

## Scenario 1: Baseline Performance Analysis

**Scenario:** The retail operations team reports that a support dashboard query for recent completed orders is slow. The query filters for completed orders on or after January 1, 2024, sorts by order date descending, and limits results to 25 documents. You need to capture baseline performance metrics and analyze whether the query is efficient.

Your baseline `explain("executionStats")` query shows: `totalDocsExamined: 15,000`, `nReturned: 25`, `executionTimeMillis: 450ms`, and `winningPlanStage: "COLLSCAN"`. A collection scan (COLLSCAN) suggests the query is not using an index.

**Assessment Questions:**

Answer the following questions to assess your understanding of query performance analysis:

- [m3_question1.md](../Inline-Questions/m3_question1.md) - Analyze the examined-to-returned ratio and identify the performance issue
- [m3_question2.md](../Inline-Questions/m3_question2.md) - Design an appropriate index using the ESR rule

---

## Scenario 2: Index Optimization and Verification

**Scenario:** You have designed and created a new index `m3_completed_orders_idx` with the key pattern `{ status: 1, orderDate: -1 }` to support the query. After running the same query again, you observe: `totalDocsExamined: 25`, `nReturned: 25`, `winningPlanStage: "FETCH"`, and `executionTimeMillis: 3ms` (150x faster). You also need to clean up experimental indexes and verify your optimization decision.

**Assessment Questions:**

Answer the following questions to assess your understanding of index optimization and validation:

- [m3_question3.md](../Inline-Questions/m3_question3.md) - Interpret the optimized execution plan and FETCH stage
- [m3_question4.md](../Inline-Questions/m3_question4.md) - Manage experimental indexes before validation
- [m3_question5.md](../Inline-Questions/m3_question5.md) - Defend your optimization using query plan quality metrics

---

## Summary

You investigated a slow query in the MongoDB support dashboard, analyzed baseline performance metrics, identified the performance bottleneck using execution statistics, designed and created an index to optimize the query, verified the improvement through before-and-after comparison, and saved evidence documenting your optimization work.
