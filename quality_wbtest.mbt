///|
fn expect_quality(text : String, expected : Int) -> Unit raise {
  match parse_quality(text) {
    Ok(value) => assert_eq(value.thousandths(), expected)
    Err(_) => fail("expected valid q-value")
  }
}

///|
fn expect_invalid_quality(text : String) -> Unit raise {
  match parse_quality(text) {
    Ok(_) => fail("expected invalid q-value")
    Err(_) => ()
  }
}

///|
test "parse valid q-values" {
  expect_quality("0", 0)
  expect_quality("0.", 0)
  expect_quality("0.0", 0)
  expect_quality("0.1", 100)
  expect_quality("0.01", 10)
  expect_quality("0.001", 1)
  expect_quality("0.123", 123)
  expect_quality("0.5", 500)
  expect_quality("0.999", 999)
  expect_quality("1", 1000)
  expect_quality("1.", 1000)
  expect_quality("1.0", 1000)
  expect_quality("1.00", 1000)
  expect_quality("1.000", 1000)
}

///|
test "reject invalid q-values" {
  expect_invalid_quality("")
  expect_invalid_quality("2")
  expect_invalid_quality("-1")
  expect_invalid_quality(".5")
  expect_invalid_quality("00")
  expect_invalid_quality("01")
  expect_invalid_quality("0.0000")
  expect_invalid_quality("0.1234")
  expect_invalid_quality("1.001")
  expect_invalid_quality("1.1")
  expect_invalid_quality("0.a")
}
