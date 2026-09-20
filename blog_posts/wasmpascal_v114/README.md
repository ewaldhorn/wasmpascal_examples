# wasmpascal v1.1.4: The WEB Unit Expands

Code notes for the blog post [wasmpascal v1.1.4: The WEB Unit Expands](https://nofuss.co.za/blog/wasmpascal_v114/).

The v1.1.4 compiler release: the `uses WEB` unit gets updates (so `paint`, `musicbox`, `colors`, and `pascalsweep` no longer hand-roll their DOM bridges), the 255-byte string concatenation cap is lifted, `Val` zeroes its target on failed parses and converts into `Single` precisely, `Str` on reals is rewritten, formatted float output (`writeln(x:8:2)`) and string `readln` get their missing host imports, `Single` arguments to `Sin`/`Cos` and friends are passed correctly, and mixing `uses WEB` with another ABI's entry point is now a compile error instead of a blank page.

This post contains only short illustrative fragments — skeletons and one-liners rather than a complete program — so there is no runnable program to preserve. Representative cases from the post:

```pascal
program paint;
uses WEB;
begin
  { ... no hand-rolled bridge anymore ... }
end.
```

```pascal
writeln(pi:0:4);          // formatted float output
writeln(x:8:2);          // width 8, 2 decimals
readln(name);            // name is a String
Val(s, v);               // v is zeroed when s fails to parse
```

Try it out live at [wasmpascal.com](https://wasmpascal.com/): try `writeln(pi:0:4)` in the console example, explore the `uses WEB` unit (see also [examples/web_dom/](../../examples/web_dom/)), or feed `Val` a string that is not a number and watch the target come back zeroed.
