///|
fn expect_selected_encoding(
  header : String,
  offers : Array[String],
  expected : String,
) -> Unit raise {
  match select_encoding(header, offers) {
    Ok(Some(actual)) => assert_eq(actual, expected)
    Ok(None) => fail("expected a selected encoding")
    Err(_) => fail("expected valid encoding negotiation")
  }
}

///|
test "parse Accept-Encoding ranges" {
  match parse_accept_encoding("gzip, br;q=0.8, *;q=0.1") {
    Ok(ranges) => {
      assert_eq(ranges.length(), 3)

      assert_eq(ranges[0].coding(), "gzip")
      assert_eq(ranges[0].quality().thousandths(), 1000)

      assert_eq(ranges[1].coding(), "br")
      assert_eq(ranges[1].quality().thousandths(), 800)

      assert_true(ranges[2].is_wildcard())
      assert_eq(ranges[2].quality().thousandths(), 100)
    }
    Err(_) => fail("expected valid Accept-Encoding header")
  }
}

///|
test "higher encoding q-value wins" {
  expect_selected_encoding(
    "gzip;q=0.5, br;q=0.9",
    ["gzip", "br", "identity"],
    "identity",
  )

  expect_selected_encoding("gzip;q=1, br;q=0.9", ["gzip", "br"], "gzip")
}

///|
test "exact encoding overrides wildcard" {
  expect_selected_encoding("*;q=1, gzip;q=0", ["gzip", "br"], "br")
}

///|
test "identity is acceptable by default" {
  expect_selected_encoding("gzip;q=0.5", ["gzip", "identity"], "identity")
}

///|
test "explicit identity can be preferred" {
  expect_selected_encoding(
    "gzip;q=0.8, identity;q=0.2",
    ["gzip", "identity"],
    "gzip",
  )
}

///|
test "identity can be explicitly rejected" {
  expect_selected_encoding(
    "gzip;q=0.5, identity;q=0",
    ["identity", "gzip"],
    "gzip",
  )
}

///|
test "wildcard zero rejects implicit identity" {
  match select_encoding("gzip;q=0, *;q=0", ["identity", "gzip"]) {
    Ok(None) => ()
    Ok(Some(_)) => fail("expected no acceptable encoding")
    Err(_) => fail("expected valid encoding negotiation")
  }
}

///|
test "explicit identity overrides wildcard zero" {
  expect_selected_encoding(
    "*;q=0, identity;q=1",
    ["gzip", "identity"],
    "identity",
  )
}

///|
test "empty Accept-Encoding only accepts identity" {
  expect_selected_encoding("", ["gzip", "identity"], "identity")

  match select_encoding("", ["gzip", "br"]) {
    Ok(None) => ()
    Ok(Some(_)) => fail("expected no acceptable encoded representation")
    Err(_) => fail("expected valid empty Accept-Encoding value")
  }
}

///|
test "encoding matching is case insensitive" {
  expect_selected_encoding("GZIP;q=1, br;q=0.5", ["gzip", "BR"], "gzip")
}

///|
test "server order breaks equal q-value ties" {
  expect_selected_encoding("gzip;q=1, br;q=1", ["br", "gzip"], "br")
}

///|
test "return none when no encoding matches" {
  match select_encoding("gzip;q=1", ["br"]) {
    Ok(None) => ()
    Ok(Some(_)) => fail("expected no acceptable encoding")
    Err(_) => fail("expected valid negotiation")
  }
}

///|
test "reject malformed Accept-Encoding values" {
  assert_true(parse_accept_encoding("gzip;q=1.1") is Err(_))
  assert_true(parse_accept_encoding("gzip;q=0.1234") is Err(_))
  assert_true(parse_accept_encoding("gzip;level=1") is Err(_))
  assert_true(parse_accept_encoding("gzip,") is Err(_))
}

///|
test "reject wildcard or malformed server offers" {
  assert_true(select_encoding("*", ["*"]) is Err(_))
  assert_true(select_encoding("*", ["gzip/br"]) is Err(_))
}
