 res←foo arg;context;event;obj;data;i;a;b
 event context←arg
 
 ⍝ Just some code to use CPU:
 :For i :In ⍳25
    b←a≡⎕JSON ⎕JSON a←10000⍴'ab'(1 2 3)
 :EndFor
 
 res←event (⎕TS) 


