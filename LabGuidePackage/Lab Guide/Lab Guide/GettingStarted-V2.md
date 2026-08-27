# Getting Started: MongoDB Customer Data Fundamentals

## Welcome

In this assessment, you are a junior database operator for a retail/e-commerce company. The company stores customer profiles, orders status and support-relevant account metadata in a local MongoDB database named **customer360**. You will complete a continuous operations journey across seven modules: **Manage → Protect → Optimize → Analyze → Secure → Troubleshoot → Atlas Operations**.

This page is orientation only and does not count toward hands-on exercise duration accounting.

## Sign in to Azure

1. Open a browser and go to <https://portal.azure.com>.
2. Sign in with the credentials assigned to your lab session:
   - Username: <inject key="AzureAdUserEmail"></inject>
   - Password: <inject key="AzureAdUserPassword"></inject>
3. If prompted, stay signed in and complete any first-use prompts using the default options provided by your instructor or lab host.
4. Confirm you are working in the assigned Azure context:
   - Subscription: <inject key="SubscriptionID"></inject>
   - Tenant: <inject key="TenantID"></inject>
   - Deployment ID: <inject key="DeploymentID"></inject>

> [!Important]
> Use only the Azure subscription and resources assigned to this lab session. Do not use personal Azure resources for Modules 1-6. Module 7 uses your own MongoDB Atlas account only when instructed.

## Lab environment overview

The CloudLabs deployment provisions one Ubuntu 22.04 Lab VM in Azure and uses an Azure Custom Script Extension to prepare the database environment. MongoDB 7.0 runs locally on the VM; Modules 1-6 operate against this local MongoDB instance. Module 7 is bring-your-own MongoDB Atlas and records local evidence only.

### Architecture

```mermaid
flowchart LR
    Candidate[Candidate browser / SSH client]
    Portal[Azure portal]
    RG[CloudLabs resource group]
    VM[Ubuntu 22.04 Lab VM]
    CSE[Azure Custom Script Extension]
    MongoDB[MongoDB 7.0 mongod service]
    DB[customer360 database]
    Collections[customers / orders / audit_events]
    Workspace[/opt/cloudlabs/mongodb-customer-data]
    Evidence[evidence and backups folders]
    Atlas[BYO MongoDB Atlas for Module 7]

    Candidate --> Portal
    Portal --> RG
    Candidate --> VM
    RG --> VM
    CSE --> VM
    VM --> MongoDB
    MongoDB --> DB
    DB --> Collections
    VM --> Workspace
    Workspace --> Evidence
    Candidate -. optional .-> Atlas
```

### Provisioned components

| Component | Purpose |
|---|---|
| Azure Virtual Machine | Ubuntu 22.04 Lab VM that hosts the hands-on environment. |
| Network resources | Virtual network, subnet, network interface, network security group, and public IP address used for VM access. |
| Azure Custom Script Extension | Bootstraps the VM by installing MongoDB 7.0, seeding data, and creating helper folders and scripts. |
| MongoDB 7.0 | Local database engine used for customer, order, audit, backup, performance, security, and troubleshooting tasks. |
| `customer360` database | Primary retail/e-commerce database used throughout the assessment. |
| Workspace folders | Standard folders under `/opt/cloudlabs/mongodb-customer-data/` for scripts, backups, evidence, data, and reset helpers. |

## Access the Azure Lab VM

You can connect to the Linux VM using the access method provided by your CloudLabs environment. Azure supports connecting to Linux virtual machines with SSH when the VM is running and the required network access is available. In the Azure portal, you can also open the VM and select **Connect** to view connection options such as native SSH.

1. In the Azure portal, search for and select **Virtual machines**.
2. Open the Ubuntu Lab VM for your deployment. The VM name should include your deployment identifier, for example **mongodb-labvm-<inject key="DeploymentID" enableCopy="false"/>**.
3. On the VM **Overview** page, verify that the VM status is **Running**.
4. Copy the VM public IP address or DNS name from the **Overview** page if your CloudLabs connection panel does not already provide it.
5. If you are using a local terminal, connect with the SSH username and password or key provided by your lab environment. A typical SSH command has this shape:

```bash
ssh labadmin@VM_PUBLIC_IP_OR_DNS_NAME
```

6. If you are using browser-based access from the lab environment, open the provided terminal session and confirm you are on the Ubuntu VM.
7. After connecting, verify the operating system and current user:

```bash
whoami
lsb_release -a
hostname
```

> [!Tip]
> If SSH fails, confirm the VM is running, confirm you are using the assigned VM for this deployment, and check the VM **Networking** page for an inbound rule that allows SSH on TCP port 22 from the expected source. If your instructor provides browser terminal access, use that method instead of changing network rules.

## Access MongoDB shell

MongoDB is installed locally on the Lab VM. At the beginning of the lab, MongoDB is intentionally available locally without authentication for Modules 1-4. Module 5 changes the security posture by enabling authentication and creating users.

1. From your SSH or browser terminal session on the Lab VM, check the MongoDB service:

```bash
systemctl status mongod --no-pager
```

2. Open the MongoDB shell:

```bash
mongosh
```

3. Switch to the lab database and list the collections:

```javascript
use customer360
show collections
```

4. Run a quick readiness check:

```javascript
db.customers.countDocuments()
db.orders.countDocuments()
db.audit_events.countDocuments()
db.customers.findOne()
```

5. Exit the shell when you are finished exploring:

```javascript
exit
```

> [!Note]
> Expected seed data is approximately 1,000 customer records and 5,000 order records. Exact values may change only if you have already completed, reset, or restored a module.

## Dataset overview

The retail dataset is intentionally small enough for beginner operations but realistic enough to practice common database tasks.

| Collection | Approximate records | What it contains |
|---|---:|---|
| `customers` | 1,000 | Customer profile fields, email, region, loyalty tier, account status, created date, and consent flags. |
| `orders` | 5,000 | Order totals, order status, order date, product category, and customer references. |
| `audit_events` | Varies | Operational notes and evidence entries that you create during the lab. |

The primary workspace is `/opt/cloudlabs/mongodb-customer-data/`.

Important subfolders:

- `/opt/cloudlabs/mongodb-customer-data/data/` — seed and generated data assets.
- `/opt/cloudlabs/mongodb-customer-data/scripts/` — scripts you create or run during exercises.
- `/opt/cloudlabs/mongodb-customer-data/backups/` — backup and restore artifacts.
- `/opt/cloudlabs/mongodb-customer-data/evidence/` — text, JSON, or log evidence files used by validations.
- `/opt/cloudlabs/mongodb-customer-data/reset/` — reset, recovery, and instructor-support helpers.

## Assessment expectations

This lab is written as a beginner assessment. The exercise pages describe required outcomes, constraints, and limited hints. They do not provide every command. The full command path is reserved for the instructor solution guide.

You are expected to:

- Work from the Lab VM unless an exercise explicitly says otherwise.
- Use `mongosh`, Linux service commands, and standard MongoDB tools where appropriate.
- Preserve evidence files in the exact folders requested by each exercise.
- Avoid storing secrets in evidence files.
- Answer the inline question in each module when it appears.
- Run validations after completing the relevant module.
- Ask your instructor before using reset scripts that could undo graded work.

## Validation usage

Each hands-on module includes an inline validation. Validations check core end-state requirements only. They are not full grading scripts and do not replace your own verification.

Use validations as follows:

1. Complete the tasks in the exercise.
2. Save any required scripts or evidence files in the specified path.
3. Select the validation control shown in the lab guide for that module.
4. If validation fails, read the message carefully, correct the end state, and run the validation again.

> [!Important]
> A passing validation means the core expected state was detected. It does not mean your explanation, evidence quality, or security choices are complete. Follow all task requirements.

## Evidence file conventions

Many modules ask you to create evidence. Keep evidence concise, readable, and non-secret.

Recommended conventions:

- Use the evidence folder: `/opt/cloudlabs/mongodb-customer-data/evidence/`.
- Use clear file names such as `module-03-explain-before.json`, `module-03-explain-after.json`, `module-05-auth-evidence.txt`, or `module-07-atlas-evidence.txt`.
- Include timestamps when useful.
- Include the command purpose and a short result summary.
- Do not paste passwords, private keys, Atlas API keys, full Atlas connection strings, or access tokens.
- If you need to document a connection string, redact credentials and host-sensitive values.

Example non-secret evidence format:

```text
Module: 7 Atlas Operations
Project or cluster name: lab project name only
Connection method used: Atlas UI or mongosh
Network access approach: current client IP allowlisted / temporary lab IP / other non-secret description
Backup setting observed: enabled / disabled / not available on tier
Troubleshooting note: checked IP access list before checking database user permissions
Secrets stored: no
```

## Reset and cleanup notes

The VM includes reset and recovery helpers under `/opt/cloudlabs/mongodb-customer-data/reset/`. These helpers are provided to recover from mistakes or to prepare for a specific module state.

General guidance:

- Do not run reset scripts casually during an assessment. They may remove work that validations expect.
- Use reset scripts only when an exercise tells you to, when your instructor tells you to, or when you need to recover from a blocked state.
- Before running a reset helper, review the script name and purpose from the terminal:

```bash
ls -la /opt/cloudlabs/mongodb-customer-data/reset/
```

- If Module 5 authentication changes block earlier tasks, ask your instructor which authentication reset helper to use.
- If Module 6 fault injection leaves MongoDB stopped, recover the service before continuing or ask your instructor for the recovery helper.
- At the end of the lab, do not delete Azure resources manually unless your instructor tells you to. CloudLabs normally manages sandbox cleanup.

## BYO MongoDB Atlas prerequisites for Module 7

Module 7 uses a bring-your-own MongoDB Atlas account or project unless your instructor marks the module as observation-only. The Azure deployment does not create or inspect Atlas resources.

Before Module 7, confirm that you have:

- Access to a MongoDB Atlas account.
- Permission to create or use an Atlas project and cluster.
- Permission to configure database users and network access entries in that Atlas project.
- A way to connect using the Atlas UI or `mongosh`.
- Agreement from your instructor about whether you should create a free/shared cluster, use an existing cluster, or complete the module as observation-only.

Evidence for Module 7 must remain local on the Lab VM and must not contain secrets. Validations only check the required local evidence file; they cannot access your Atlas tenant.

## What you will complete

| Module | Theme | Outcome |
|---|---|---|
| 1 | Administration & Architecture | Inspect data, create a customer, apply validation, update a record, and record an audit event. |
| 2 | Backup, Recovery & Resilience | Create a reusable backup process, simulate data loss, restore, and verify recovery. |
| 3 | Performance Tuning & Optimization | Use `explain()`, create an index, and capture before/after performance evidence. |
| 4 | Operational Analytics | Build an aggregation script with `$match`, `$group`, `$project`, and `$sort`. |
| 5 | Security & Compliance | Enable authentication, create users and roles, and prove least-privilege access. |
| 6 | Linux & Platform Operations | Diagnose and recover a stopped and disabled `mongod` service. |
| 7 | Atlas & Cloud Operations | Operate a BYO Atlas environment and save non-secret local operations evidence. |

You are now ready to begin Exercise 01.

## After publishing

> [!Note] These steps run **after** you push the template to CloudLabs — they verify CloudLabs can actually serve this lab guide to candidates.

- **Verify docs-proxy access:** open Templates → your template → **Lab Guide Settings** in <https://admin.cloudlabs.ai> and confirm CloudLabs can reach this repo via the docs proxy. If the repo is private, configure GitHub access at the template level.
- **Verify inline questions and inline validations:** sign in to <https://admin.cloudlabs.ai>, open your template, and walk through one full lab run to confirm every `<question>` and `<validation step="..."/>` renders correctly. Fix any that don't resolve.
