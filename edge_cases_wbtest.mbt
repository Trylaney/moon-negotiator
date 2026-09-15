///|
test "media selection respects explicit q zero over wildcard" {
  match
    select_media_type("text/*;q=1, text/html;q=0", ["text/html", "text/plain"]) {
    Ok(Some(actual)) => assert_eq(actual, "text/plain")
    Ok(None) => fail("expected an acceptable media type")
    Err(_) => fail("expected valid negotiation")
  }
}

///|
test "more specific media range controls quality even when lower" {
  match
    select_media_type("*/*;q=1, application/json;q=0.2", [
      "application/json", "text/plain",
    ]) {
    Ok(Some(actual)) => assert_eq(actual, "text/plain")
    Ok(None) => fail("expected an acceptable media type")
    Err(_) => fail("expected valid negotiation")
  }
}

///|
test "media selection handles q zero everywhere" {
  match select_media_type("*/*;q=0", ["text/html", "application/json"]) {
    Ok(None) => ()
    Ok(Some(_)) => fail("expected no acceptable media type")
    Err(_) => fail("expected valid negotiation")
  }
}

///|
test "encoding explicit coding overrides wildcard quality" {
  match select_encoding("*;q=1, gzip;q=0.1", ["gzip", "br"]) {
    Ok(Some(actual)) => assert_eq(actual, "br")
    Ok(None) => fail("expected an acceptable encoding")
    Err(_) => fail("expected valid negotiation")
  }
}

///|
test "encoding explicit zero rejects only that coding" {
  match select_encoding("gzip;q=0, *;q=0.5", ["gzip", "br"]) {
    Ok(Some(actual)) => assert_eq(actual, "br")
    Ok(None) => fail("expected an acceptable encoding")
    Err(_) => fail("expected valid negotiation")
  }
}

///|
test "identity remains preferred when implicit and higher quality" {
  match select_encoding("gzip;q=0.8", ["gzip", "identity"]) {
    Ok(Some(actual)) => assert_eq(actual, "identity")
    Ok(None) => fail("expected identity to remain acceptable")
    Err(_) => fail("expected valid negotiation")
  }
}

///|
test "language specific zero overrides broader positive range" {
  match select_language("en;q=1, en-US;q=0", ["en-US", "en-GB"]) {
    Ok(Some(actual)) => assert_eq(actual, "en-GB")
    Ok(None) => fail("expected an acceptable language")
    Err(_) => fail("expected valid negotiation")
  }
}

///|
test "language prefix requires hyphen boundary" {
  match parse_accept_language("en") {
    Ok(ranges) =>
      match ranges[0].matches("english") {
        Ok(actual) => assert_eq(actual, false)
        Err(_) => fail("expected structurally valid language tag")
      }
    Err(_) => fail("expected valid language range")
  }
}

///|
test "wildcard language zero rejects all offers" {
  match select_language("*;q=0", ["en-US", "zh-CN"]) {
    Ok(None) => ()
    Ok(Some(_)) => fail("expected no acceptable language")
    Err(_) => fail("expected valid negotiation")
  }
}

///|
test "quality parser rejects excessive precision and non numeric input" {
  assert_true(parse_quality("0.0001") is Err(_))
  assert_true(parse_quality("1.0000") is Err(_))
  assert_true(parse_quality("abc") is Err(_))
  assert_true(parse_quality("0.-1") is Err(_))
}
