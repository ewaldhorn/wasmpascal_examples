{ Snippets from the blog post "wasmpascal v0.4.0: Ternaries, Xonix, and more"
  (https://nofuss.co.za/blog/wasmpascal_v040/).
  Before: classic if..then..else statement. After: v0.4.0 inline ternary. }

{ Before }
if n <= 1 then
  FibRec := n
else
  FibRec := FibRec(n - 1) + FibRec(n - 2);

{ After (v0.4.0 ternary) }
FibRec := if n <= 1 then n else FibRec(n - 1) + FibRec(n - 2);
