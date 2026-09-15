///|
fn expect_media_match(
  range_text : String,
  offer : String,
  expected : Bool,
) -> Unit raise {
  match parse_accept(range_text) {
    Err(_) => fail("expected valid media range")
    Ok(ranges) => {
      if ranges.length() != 1 {
        fail("expected exactly one media range")
      }

      match ranges[0].matches(offer) {
        Ok(actual) => assert_eq(actual, expected)
        Err(_) => fail("expected valid concrete media type")
      }
    }
  }
}

///|
fn expect_specificity(range_text : String, expected : Int) -> Unit raise {
  match parse_accept(range_text) {
    Err(_) => fail("expected valid media range")
    Ok(ranges) => {
      if ranges.length() != 1 {
        fail("expected exactly one media range")
      }

      assert_eq(ranges[0].specificity(), expected)
    }
  }
}

///|
test "exact media range matches exact media type" {
  expect_media_match("text/html", "text/html", true)
  expect_media_match("application/json", "application/json", true)
  expect_media_match("text/html", "application/json", false)
}

///|
test "type wildcard matches subtypes of the same type" {
  expect_media_match("text/*", "text/html", true)
  expect_media_match("text/*", "text/plain", true)
  expect_media_match("text/*", "application/json", false)
}

///|
test "global wildcard matches concrete media types" {
  expect_media_match("*/*", "text/html", true)
  expect_media_match("*/*", "application/json", true)
  expect_media_match("*/*", "image/png", true)
}

///|
test "media type matching is case insensitive" {
  expect_media_match("TEXT/HTML", "text/html", true)
  expect_media_match("application/JSON", "APPLICATION/json", true)
  expect_media_match("Text/*", "TEXT/plain", true)
}

///|
test "media range specificity is deterministic" {
  expect_specificity("*/*", 0)
  expect_specificity("text/*", 1)
  expect_specificity("text/html", 2)
}

///|
test "matching rejects wildcard server offers" {
  match parse_accept("text/*") {
    Err(_) => fail("expected valid media range")
    Ok(ranges) => {
      assert_true(ranges[0].matches("text/*") is Err(_))
      assert_true(ranges[0].matches("*/*") is Err(_))
    }
  }
}

///|
test "matching rejects malformed server offers" {
  match parse_accept("text/*") {
    Err(_) => fail("expected valid media range")
    Ok(ranges) => {
      assert_true(ranges[0].matches("text") is Err(_))
      assert_true(ranges[0].matches("") is Err(_))
      assert_true(ranges[0].matches("/html") is Err(_))
    }
  }
}
