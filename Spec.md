MongoDB Customer Data Fundamentals

Lab Overview
• Cloud: Azure
• Duration: 75 minutes
• Exercises: 7 (Administration & Architecture: Manage customer records, Backup, Recovery & Resilience: Protect the dataset, Performance Tuning & Optimization: Optimize a slow query, High Availability & Operational Support: Analyze business metrics, Security & Compliance: Secure MongoDB access, Linux & Platform Operations: Troubleshoot stopped MongoDB service, Atlas & Cloud Operations: Operate a BYO Atlas environment)
• Validations: 7
• Deployed services: Azure Virtual Machine (Ubuntu 22.04), Azure VM Custom Script Extension, Virtual Network, Subnet, Network Interface, Network Security Group, Public IP Address, native MongoDB 7.0 on the Lab VM
• Scenario: Candidates act as junior database operators for a retail/e-commerce company that stores customer profiles, orders, loyalty status, and support-relevant account metadata in MongoDB. The assessment follows a continuous operational journey through managing customer records, protecting and restoring data, optimizing queries, analyzing business metrics, securing access, troubleshooting the Linux MongoDB service, and documenting bring-your-own MongoDB Atlas operations. A single-stage Azure ARM deployment provisions an Ubuntu 22.04 Lab VM, installs native MongoDB 7.0, and seeds approximately 1,000 customers and 5,000 orders in the customer360 database.

This Package Includes

Deliverables Included in the Package
• Lab Guide
• Master Document
• Inline Validations
• Inline Questions / Assessments
• Azure ARM deployment package with Custom Script Extension bootstrap
• Custom RBAC role artifact
• Custom Azure Policy artifact
• Solution guide and beginner assessment summary content

Inline Validations
Pre-configured inline validations enabled

Inline Assessment Questions
Single-choice questions (Simple question types only)

Lab Guide Preview
Preview link for the lab guide documentation:
[\[CloudLabs LabGuide Preview\]](https://experience.cloudlabs.ai/#labguidepreview/<GUID>/1)

Lab Environment Setup & Deployment
Lab provisioning and setup include one or more of the following components:
• ARM template deployment
• Custom Script Extension (CSE)
• Custom image-based environment setup
• Supporting deployment configurations as required

Learner Flow Summary
• Level and format: Beginner assessment with limited command hints in the lab guide and full commands in the instructor solution.
• Estimated flow: Connect to the Ubuntu 22.04 Lab VM, inspect the local MongoDB customer360 database, complete seven equal-weight operational modules, answer seven single-choice inline questions, and run seven core end-state validations.
• Azure deployment summary: One ARM stage deploys the Lab VM and supporting networking resources, then applies a Custom Script Extension that installs MongoDB 7.0, starts mongod, creates workspace folders, seeds the retail dataset, and provides reset and fault-injection helpers.
• Known prerequisite: Module 7 requires the learner to bring access to their own MongoDB Atlas account/project unless the instructor marks the module as observation-only; validations check only local non-secret Atlas evidence.

Exclusions
This package does not include:
• Scoring or grading mechanisms for inline validations
• Complex or advanced inline question types