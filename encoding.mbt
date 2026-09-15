///|
pub struct EncodingRange {
  coding : String
  quality : Quality
} derive(Eq, Debug)

///|
pub fn EncodingRange::coding(self : EncodingRange) -> String {
  self.coding
}

///|
pub fn EncodingRange::quality(self : EncodingRange) -> Quality {
  self.quality
}

///|
pub fn EncodingRange::is_wildcard(self : EncodingRange) -> Bool {
  self.coding == "*"
}

///|
fn valid_encoding_token(text : String) -> Bool {
  if text.length() == 0 {
    return false
  }

  for i = 0; i < text.length(); i = i + 1 {
    let unit = text.code_unit_at(i)

    if is_ows(unit) || unit == ',' || unit == ';' || unit == '=' || unit == '/' {
      return false
    }
  }

  true
}

///|
fn parse_encoding_range(raw : String) -> Result[EncodingRange, ParseError] {
  let text = trim_ows(raw)

  if text.length() == 0 {
    return Err(InvalidEncodingRange(raw))
  }

  let parts = split_ascii(text, ';')
  let coding = trim_ows(parts[0])

  if !valid_encoding_token(coding) {
    return Err(InvalidEncodingRange(raw))
  }

  let mut quality = Quality::{ value: 1000, }
  let mut saw_quality = false

  for i = 1; i < parts.length(); i = i + 1 {
    let parameter = trim_ows(parts[i])

    if parameter.length() == 0 {
      return Err(InvalidEncodingRange(raw))
    }

    match find_ascii(parameter, '=') {
      None => return Err(InvalidEncodingRange(raw))
      Some(equal) => {
        let name = trim_ows(parameter[0:equal].to_owned())
        let value = trim_ows(parameter[equal + 1:parameter.length()].to_owned())

        if name == "q" || name == "Q" {
          if saw_quality {
            return Err(InvalidEncodingRange(raw))
          }

          saw_quality = true

          match parse_quality(value) {
            Ok(parsed) => quality = parsed
            Err(error) => return Err(error)
          }
        } else {
          return Err(UnsupportedEncodingParameter(parameter))
        }
      }
    }
  }

  Ok(EncodingRange::{ coding, quality, })
}

///|
/// Parses an Accept-Encoding field value.
///
/// An empty field value is valid and means that no content coding is desired.
pub fn parse_accept_encoding(
  header : String,
) -> Result[Array[EncodingRange], ParseError] {
  if trim_ows(header).length() == 0 {
    return Ok([])
  }

  let result : Array[EncodingRange] = []

  for raw in split_ascii(header, ',') {
    match parse_encoding_range(raw) {
      Ok(range) => result.push(range)
      Err(error) => return Err(error)
    }
  }

  Ok(result)
}

///|
fn find_encoding_quality(ranges : Array[EncodingRange], offer : String) -> Int? {
  // An explicit coding takes precedence over wildcard.
  for range in ranges {
    if ascii_equal_ignore_case(range.coding(), offer) {
      return Some(range.quality().thousandths())
    }
  }

  for range in ranges {
    if range.is_wildcard() {
      return Some(range.quality().thousandths())
    }
  }

  None
}

///|
fn identity_quality(ranges : Array[EncodingRange]) -> Int {
  // An explicit identity entry always wins.
  for range in ranges {
    if ascii_equal_ignore_case(range.coding(), "identity") {
      return range.quality().thousandths()
    }
  }

  // identity is normally acceptable by default. A wildcard only
  // suppresses it when the wildcard explicitly has q=0.
  for range in ranges {
    if range.is_wildcard() && range.quality().thousandths() == 0 {
      return 0
    }
  }

  1000
}

///|
/// Selects a content coding from concrete server-provided offers.
///
/// Policy:
/// - Explicit coding entries override wildcard entries.
/// - Higher q-value wins.
/// - `identity` is acceptable by default unless explicitly excluded.
/// - Equal q-values preserve server offer order.
/// - An empty Accept-Encoding value only allows `identity`.
pub fn select_encoding(
  header : String,
  offers : Array[String],
) -> Result[String?, ParseError] {
  let ranges = match parse_accept_encoding(header) {
    Ok(parsed) => parsed
    Err(error) => return Err(error)
  }

  let empty_header = trim_ows(header).length() == 0

  let mut selected : String? = None
  let mut selected_quality = -1

  for raw_offer in offers {
    let offer = trim_ows(raw_offer)

    if offer.length() == 0 || offer == "*" || !valid_encoding_token(offer) {
      return Err(InvalidEncodingRange(raw_offer))
    }

    let quality = if ascii_equal_ignore_case(offer, "identity") {
      identity_quality(ranges)
    } else if empty_header {
      0
    } else {
      match find_encoding_quality(ranges, offer) {
        Some(value) => value
        None => 0
      }
    }

    if quality > 0 && (selected is None || quality > selected_quality) {
      selected = Some(offer)
      selected_quality = quality
    }
  }

  Ok(selected)
}
