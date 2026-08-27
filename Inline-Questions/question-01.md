## MetaData
Question Type : Single Choice

## Question
The `customers` collection validator requires `status` to be either `active` or `inactive` and `consent.marketing` to be a Boolean. A new retail customer insert is rejected with document validation failure. The attempted document includes `status: "active"` and `consent: { marketing: "true" }`. Which change is most likely to make the insert valid while preserving the intended customer status and consent?

## Options
Option 1 : Change `consent.marketing` from the string `"true"` to the Boolean `true`.
Option 2 : Remove the entire `consent` field from the customer document.
Option 3 : Change `status` from `"active"` to the Boolean `true`.
Option 4 : Change `status` from `"active"` to `"pending"`.

## Answers
Option 1 : 1

## Correct Answer Feedback
Option 1 is correct answer, because `"true"` is a string rather than the Boolean value required by the validator; using `true` preserves the intended consent while `status: "active"` already satisfies the allowed status values.

## Incorrect Answer Feedback
Selected Option is not correct Option 1 is the correct answer

## Number of Retries
1