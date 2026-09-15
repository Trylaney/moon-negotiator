///|
fn expect_selected_media(
  header : String,
  offers : Array[String],
  expected : String,
) -> Unit raise {
  match select_media_type(header, offers) {
    Ok(Some(actual)) => assert_eq(actual, expected)
    Ok(None) => fail("expected a selected media type")
    Err(_) => fail("expected valid media negotiation")
  }
}

///|
test "higher effective q-value wins" {
  expect_selected_media(
    "text/*;q=0.8, application/json;q=0.9",
    ["text/html", "application/json"],
    "application/json",
  )
}

///|
test "specific range determines effective quality" {
  expect_selected_media(
    "text/*;q=1, text/html;q=0.5",
    ["text/html", "text/plain"],
    "text/plain",
  )
}

///|
test "higher specificity wins when effective quality ties" {
  expect_selected_media(
    "text/*;q=0.8, text/html;q=0.8",
    ["text/plain", "text/html"],
    "text/html",
  )
}

///|
test "server offer order breaks a complete tie" {
  expect_selected_media(
    "*/*;q=0.5",
    ["application/json", "text/html"],
    "application/json",
  )
}

///|
test "q zero makes an offer unacceptable" {
  expect_selected_media(
    "text/html;q=0, application/json;q=0.5",
    ["text/html", "application/json"],
    "application/json",
  )
}

///|
test "return none when nothing is acceptable" {
  match select_media_type("application/json", ["text/html", "image/png"]) {
    Ok(None) => ()
    Ok(Some(_)) => fail("expected no acceptable media type")
    Err(_) => fail("expected valid negotiation")
  }
}

///|
test "return none when every matching range has q zero" {
  match select_media_type("text/*;q=0", ["text/html", "text/plain"]) {
    Ok(None) => ()
    Ok(Some(_)) => fail("expected no acceptable media type")
    Err(_) => fail("expected valid negotiation")
  }
}

///|
test "selection is case insensitive" {
  expect_selected_media(
    "TEXT/HTML;q=1, application/json;q=0.5",
    ["text/html", "APPLICATION/JSON"],
    "text/html",
  )
}

///|
test "selection trims optional whitespace from server offers" {
  expect_selected_media("text/html", ["  text/html  "], "text/html")
}

///|
test "reject wildcard server offers" {
  assert_true(select_media_type("*/*", ["text/*"]) is Err(_))
}

///|
test "reject malformed server offers" {
  assert_true(select_media_type("*/*", ["not-a-media-type"]) is Err(_))
}
