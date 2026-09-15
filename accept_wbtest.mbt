///|
test "parse a single media range" {
  match parse_accept("text/html") {
    Ok(ranges) => {
      assert_eq(ranges.length(), 1)
      assert_eq(ranges[0].major_type(), "text")
      assert_eq(ranges[0].subtype(), "html")
      assert_eq(ranges[0].quality().thousandths(), 1000)
    }
    Err(_) => fail("expected valid Accept header")
  }
}

///|
test "parse multiple media ranges and q-values" {
  match
    parse_accept("text/html, application/json;q=0.9, text/*;q=0.5, */*;q=0.1") {
    Ok(ranges) => {
      assert_eq(ranges.length(), 4)

      assert_eq(ranges[0].major_type(), "text")
      assert_eq(ranges[0].subtype(), "html")
      assert_eq(ranges[0].quality().thousandths(), 1000)

      assert_eq(ranges[1].major_type(), "application")
      assert_eq(ranges[1].subtype(), "json")
      assert_eq(ranges[1].quality().thousandths(), 900)

      assert_eq(ranges[2].major_type(), "text")
      assert_eq(ranges[2].subtype(), "*")
      assert_eq(ranges[2].quality().thousandths(), 500)

      assert_eq(ranges[3].major_type(), "*")
      assert_eq(ranges[3].subtype(), "*")
      assert_eq(ranges[3].quality().thousandths(), 100)
    }
    Err(_) => fail("expected valid Accept header")
  }
}

///|
test "trim optional whitespace" {
  match parse_accept("  text/html ; q=0.8 , application/json  ") {
    Ok(ranges) => {
      assert_eq(ranges.length(), 2)
      assert_eq(ranges[0].major_type(), "text")
      assert_eq(ranges[0].subtype(), "html")
      assert_eq(ranges[0].quality().thousandths(), 800)
      assert_eq(ranges[1].quality().thousandths(), 1000)
    }
    Err(_) => fail("expected optional whitespace to be accepted")
  }
}

///|
test "reject malformed media ranges" {
  assert_true(parse_accept("") is Err(_))
  assert_true(parse_accept("text") is Err(_))
  assert_true(parse_accept("/html") is Err(_))
  assert_true(parse_accept("text/") is Err(_))
  assert_true(parse_accept("*/json") is Err(_))
  assert_true(parse_accept("text/html,") is Err(_))
  assert_true(parse_accept("text/html;q=1.1") is Err(_))
  assert_true(parse_accept("text/html;q=0.1234") is Err(_))
  assert_true(parse_accept("text/html;q=0.5;q=0.4") is Err(_))
}

///|
test "reject unsupported media parameters explicitly" {
  assert_true(parse_accept("text/html;level=1") is Err(_))
}
