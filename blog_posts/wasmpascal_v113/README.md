# wasmpascal v1.1.3: The Compiler Learns to Complain

Code notes for the blog post [wasmpascal v1.1.3: The Compiler Learns to Complain](https://nofuss.co.za/blog/wasmpascal_v113/).

The v1.1.3 compiler release: it now rejects programs it used to accept silently (wrong parameter counts, type mismatches, missing `;`), validates builtin arity (`GotoXY`, `GetMem`, `FillChar`, `Move`, …), fixes `{$IF}/{$ELSE}` conditional compilation and unit initialisation sections, reports diagnostics with positions and source excerpts, and ships its first warnings and hints. It also fixes by-value record and array semantics.

This post contains only short illustrative fragments — all of them examples of code the compiler now **rejects**, so there is no runnable program to preserve. Representative cases from the post:

```pascal
P();                   // one-param P called with no params at all
P(1, 2);               // or called with too many
x := s;                // s is a String, x is an Integer
```

```pascal
GotoXY(5);             // the console call was emitted as NOTHING
GetMem(a);             // no allocation, no error
FillChar(ar2, 8);      // the array was left untouched
```

Try it out live at [wasmpascal.com](https://wasmpascal.com/): write a deliberate typo, call `GotoXY` with one argument, or drop a semicolon, and watch the compiler tell you exactly what it thinks.
