 res←echo arg;context;event;obj;data
 event context←arg
  ⍝ Just return event with timestamp.
 res←event (⎕TS)


