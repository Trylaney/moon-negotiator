# moon-negotiator

Small HTTP content negotiation utilities for MoonBit.

`moon-negotiator` parses common HTTP `Accept*` request headers and helps a server choose a compatible representation from the values it can actually provide.

The project currently supports:

- `Accept`
- `Accept-Encoding`
- `Accept-Language`

It is intentionally a small library rather than an HTTP framework.

## Why

HTTP servers often need to choose between multiple response formats, compression methods, or language variants.

Without a reusable negotiation library, applications tend to implement this logic repeatedly, especially around q-values, wildcards, specificity, and `identity` handling.

`moon-negotiator` keeps that logic in a small dependency-free MoonBit package.

## Quick Example

```moonbit
let header = "text/*;q=0.8, application/json;q=0.9"
let offers = ["text/html", "application/json"]

match @negotiator.select_media_type(header, offers) {
  Ok(Some(selected)) => println(selected)
  Ok(None) => println("No acceptable media type")
  Err(_) => println("Invalid negotiation input")
}
```

Output:

```text
application/json
```

## API

### Media Type Negotiation

```moonbit
parse_accept(header)
select_media_type(header, offers)
```

Example:

```text
Accept:
text/*;q=0.8, application/json;q=0.9

Server offers:
text/html
application/json

Selected:
application/json
```

Media ranges support:

```text
text/html
text/*
*/*
```

For a concrete server offer, the most specific matching media range determines its effective q-value.

When offers have equal effective quality, matching specificity is used as the next tie-breaker. A complete tie preserves server offer order.

## Content Encoding Negotiation

```moonbit
parse_accept_encoding(header)
select_encoding(header, offers)
```

Example:

```text
Accept-Encoding:
br;q=1, gzip;q=0.8, identity;q=0.1

Server offers:
gzip
br
identity

Selected:
br
```

The implementation handles the special `identity` coding separately.

An explicit coding entry overrides `*`, and `identity` remains acceptable by default unless the header excludes it.

## Language Negotiation

```moonbit
parse_accept_language(header)
filter_languages(header, offers)
select_language(header, offers)
```

Example:

```text
Accept-Language:
zh-CN, en-US;q=0.8

Server offers:
en-US
zh-CN
ja-JP

Selected:
zh-CN
```

Language matching uses RFC 4647 Basic Filtering semantics.

For example:

```text
en
```

can match:

```text
en-US
en-GB
```

but a more specific range does not match a shorter tag in reverse.

## q-values

HTTP q-values are stored internally as integers from `0` to `1000`.

Examples:

```text
q=0      -> 0
q=0.5    -> 500
q=0.999  -> 999
q=1      -> 1000
```

This avoids floating-point comparison issues and matches the HTTP q-value precision limit of three decimal places.

## Examples

Three runnable examples are included.

Media type negotiation:

```sh
moon run examples/media
```

Expected output:

```text
Selected media type: application/json
```

Content encoding negotiation:

```sh
moon run examples/encoding
```

Expected output:

```text
Selected encoding: br
```

Language negotiation:

```sh
moon run examples/language
```

Expected output:

```text
Selected language: zh-CN
```

## Development

Check the project:

```sh
moon check
```

Run all tests:

```sh
moon test
```

Format the source:

```sh
moon fmt
```

The current test suite covers parsing, q-values, wildcards, specificity, server-order tie-breaking, `identity`, Basic Language Filtering, malformed input, and negotiation edge cases.

## Scope

The current version deliberately focuses on a small negotiation core.

It does not provide:

- an HTTP server or middleware framework
- compression or decompression implementations
- a locale database
- RFC 4647 Extended Filtering or Lookup
- complete semantic validation of BCP 47 language tags
- general HTTP header parsing
- media type parameters other than `q`

In particular, a value such as:

```text
text/html;level=1
```

is currently rejected instead of silently ignoring the unsupported parameter.

## Standards

The implementation is based on the negotiation concepts defined in:

- RFC 9110 — HTTP Semantics
- RFC 4647 — Matching of Language Tags

The project intentionally implements a limited, documented subset rather than claiming complete coverage of either standard.

## License

Apache-2.0