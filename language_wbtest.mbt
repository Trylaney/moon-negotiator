///|
fn expect_selected_language(
  header : String,
  offers : Array[String],
  expected : String,
) -> Unit raise {
  match select_language(header, offers) {
    Ok(Some(actual)) => assert_eq(actual, expected)
    Ok(None) => fail("expected a selected language")
    Err(_) => fail("expected valid language negotiation")
  }
}

///|
fn expect_language_match(
  range_text : String,
  tag : String,
  expected : Bool,
) -> Unit raise {
  match parse_accept_language(range_text) {
    Err(_) => fail("expected valid language range")
    Ok(ranges) => {
      if ranges.length() != 1 {
        fail("expected exactly one language range")
      }

      match ranges[0].matches(tag) {
        Ok(actual) => assert_eq(actual, expected)
        Err(_) => fail("expected valid language tag")
      }
    }
  }
}

///|
test "parse Accept-Language ranges" {
  match parse_accept_language("zh-CN, zh;q=0.9, en;q=0.8") {
    Ok(ranges) => {
      assert_eq(ranges.length(), 3)
      assert_eq(ranges[0].language_range(), "zh-CN")
      assert_eq(ranges[0].quality().thousandths(), 1000)
      assert_eq(ranges[1].language_range(), "zh")
      assert_eq(ranges[1].quality().thousandths(), 900)
      assert_eq(ranges[2].quality().thousandths(), 800)
    }
    Err(_) => fail("expected valid Accept-Language header")
  }
}

///|
test "basic filtering matches exact and prefix tags" {
  expect_language_match("zh", "zh", true)
  expect_language_match("zh", "zh-CN", true)
  expect_language_match("zh", "zh-Hant-TW", true)
  expect_language_match("zh", "en-US", false)
}

///|
test "basic filtering does not match in reverse" {
  expect_language_match("zh-CN", "zh", false)
  expect_language_match("en-US", "en", false)
}

///|
test "language matching is case insensitive" {
  expect_language_match("ZH-cn", "zh-CN", true)
  expect_language_match("EN", "en-GB", true)
}

///|
test "language wildcard matches any valid tag" {
  expect_language_match("*", "en-US", true)
  expect_language_match("*", "zh-Hant-TW", true)
}

///|
test "longest language range determines effective quality" {
  expect_selected_language("en;q=1, en-US;q=0.3", ["en-US", "en-GB"], "en-GB")
}

///|
test "higher language q-value wins" {
  expect_selected_language("zh;q=0.7, en;q=0.9", ["zh-CN", "en-US"], "en-US")
}

///|
test "more specific matching range breaks equal q tie" {
  expect_selected_language("en;q=0.8, fr-FR;q=0.8", ["en-US", "fr-FR"], "fr-FR")
}

///|
test "server order breaks a complete language tie" {
  expect_selected_language("en;q=0.8, fr;q=0.8", ["fr-FR", "en-US"], "fr-FR")
}

///|
test "q zero makes a language unacceptable" {
  expect_selected_language("zh;q=0, en;q=0.5", ["zh-CN", "en-US"], "en-US")
}

///|
test "filter languages preserves server offer order" {
  match
    filter_languages("zh;q=1, en;q=0.5", ["en-US", "ja-JP", "zh-CN", "en-GB"]) {
    Ok(result) => {
      assert_eq(result.length(), 3)
      assert_eq(result[0], "en-US")
      assert_eq(result[1], "zh-CN")
      assert_eq(result[2], "en-GB")
    }
    Err(_) => fail("expected valid filtering")
  }
}

///|
test "return none when no language is acceptable" {
  match select_language("zh;q=0", ["zh-CN", "en-US"]) {
    Ok(None) => ()
    Ok(Some(_)) => fail("expected no acceptable language")
    Err(_) => fail("expected valid negotiation")
  }
}

///|
test "empty Accept-Language value selects nothing" {
  match select_language("", ["en-US", "zh-CN"]) {
    Ok(None) => ()
    Ok(Some(_)) => fail("expected no selected language")
    Err(_) => fail("expected valid empty field value")
  }
}

///|
test "reject malformed language ranges and tags" {
  assert_true(parse_accept_language("en--US") is Err(_))
  assert_true(parse_accept_language("en-*-US") is Err(_))
  assert_true(parse_accept_language("en;q=1.1") is Err(_))
  assert_true(parse_accept_language("en;level=1") is Err(_))

  match parse_accept_language("en") {
    Ok(ranges) => {
      assert_true(ranges[0].matches("en--US") is Err(_))
      assert_true(ranges[0].matches("*") is Err(_))
    }
    Err(_) => fail("expected valid language range")
  }
}
