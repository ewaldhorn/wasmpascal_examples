# Operators & precedence

> Part of the WasmPascal in-browser **Pascal quick reference** (the `?` help overlay). Source: `webpascal/index.html`.

- `not`, unary `-`
- `*` `/` `div` `mod` `and`
- `+` `-` `or` `xor`
- `=` `<>` `<` `>` `<=` `>=` `in`

Unsigned `div`/`mod` need *both* operands unsigned — a `Cardinal mod <literal>` promotes to signed and can go negative. Use a power-of-two mask (`seed and (RANGE-1)`) instead.

Set operators (both operands `set of`): `+` union, `-` difference, `*` intersection; `=` `<>` equality; `<=` `>=` subset/superset; `x in s` membership.
