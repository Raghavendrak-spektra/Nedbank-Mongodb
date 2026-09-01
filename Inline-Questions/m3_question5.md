## MetaData
Question Type : Single Choice

## Question
You are documenting your performance optimization work for the support dashboard query. Your evidence file shows baseline execution time of 450ms with 15,000 documents examined, and optimized execution time of 3ms with 25 documents examined using your `m3_completed_orders_idx` index. However, a colleague challenges your conclusion, stating that elapsed time can vary on lab VMs and should not be the primary optimization metric. What is the most technically sound defense of your optimization based on query plan quality?

## Options
Option 1 : Propose that both queries should be repeated multiple times and averaged to establish statistical significance before claiming optimization.

Option 2 : Insist that the 150x improvement in execution time is definitive proof and elapsed time variations are irrelevant to performance analysis.

Option 3 : Argue that the reduction in totalDocsExamined from 15,000 to 25 documents proves the index supports an efficient query plan, regardless of elapsed time variation, because it directly reduces I/O and CPU work.

Option 4 : Admit that the optimization may not be valid since timing varies on lab VMs and suggest retesting on a production server.

## Answers
Option 3 : 1

## Correct Answer Feedback
Option 3 is correct

## Number of Retries
1
