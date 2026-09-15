///|
pub struct MediaRange {
  major : String
  minor : String
  quality : Quality
} derive(Eq, Debug)

///|
pub fn MediaRange::major_type(self : MediaRange) -> String {
  self.major
}

///|
pub fn MediaRange::subtype(self : MediaRange) -> String {
  self.minor
}

///|
pub fn MediaRange::quality(self : MediaRange) -> Quality {
  self.quality
}

///|
pub fn MediaRange::is_type_wildcard(self : MediaRange) -> Bool {
  self.major == "*"
}

///|
pub fn MediaRange::is_subtype_wildcard(self : MediaRange) -> Bool {
  self.minor == "*"
}

///|
fn is_ows(unit : UInt16) -> Bool {
  unit == ' ' || unit == '\t'
}

///|
fn trim_ows(text : String) -> String {
  let len = text.length()
  let mut start = 0
  let mut end = len

  while start < end && is_ows(text.code_unit_at(start)) {
    start = start + 1
  }

  while end > start && is_ows(text.code_unit_at(end - 1)) {
    end = end - 1
  }

  text[start:end].to_owned()
}

///|
fn split_ascii(text : String, delimiter : UInt16) -> Array[String] {
  let result : Array[String] = []
  let len = text.length()
  let mut start = 0

  for i = 0; i < len; i = i + 1 {
    if text.code_unit_at(i) == delimiter {
      result.push(text[start:i].to_owned())
      start = i + 1
    }
  }

  result.push(text[start:len].to_owned())
  result
}

///|
fn find_ascii(text : String, target : UInt16) -> Int? {
  for i = 0; i < text.length(); i = i + 1 {
    if text.code_unit_at(i) == target {
      return Some(i)
    }
  }
  None
}

///|
fn contains_ascii(text : String, target : UInt16) -> Bool {
  find_ascii(text, target) is Some(_)
}

///|
fn valid_media_component(text : String) -> Bool {
  if text.length() == 0 {
    return false
  }

  for i = 0; i < text.length(); i = i + 1 {
    let unit = text.code_unit_at(i)
    if is_ows(unit) || unit == '/' || unit == ';' || unit == ',' || unit == '=' {
      return false
    }
  }

  true
}

///|
fn parse_media_name(text : String) -> Result[(String, String), ParseError] {
  match find_ascii(text, '/') {
    None => Err(InvalidMediaRange(text))
    Some(slash) => {
      let major = trim_ows(text[0:slash].to_owned())
      let minor = trim_ows(text[slash + 1:text.length()].to_owned())

      if major.length() == 0 ||
        minor.length() == 0 ||
        contains_ascii(minor, '/') ||
        !valid_media_component(major) ||
        !valid_media_component(minor) {
        return Err(InvalidMediaRange(text))
      }

      if major == "*" && minor != "*" {
        return Err(InvalidMediaRange(text))
      }

      Ok((major, minor))
    }
  }
}

///|
fn parse_media_range(raw : String) -> Result[MediaRange, ParseError] {
  let text = trim_ows(raw)

  if text.length() == 0 {
    return Err(InvalidMediaRange(raw))
  }

  let parts = split_ascii(text, ';')

  match parse_media_name(trim_ows(parts[0])) {
    Err(error) => Err(error)
    Ok((major, minor)) => {
      let mut quality = Quality::{ value: 1000, }
      let mut saw_quality = false

      for i = 1; i < parts.length(); i = i + 1 {
        let parameter = trim_ows(parts[i])

        if parameter.length() == 0 {
          return Err(InvalidMediaRange(raw))
        }

        match find_ascii(parameter, '=') {
          None => return Err(InvalidMediaRange(raw))
          Some(equal) => {
            let name = trim_ows(parameter[0:equal].to_owned())
            let value = trim_ows(
              parameter[equal + 1:parameter.length()].to_owned(),
            )

            if name == "q" || name == "Q" {
              if saw_quality {
                return Err(InvalidMediaRange(raw))
              }

              saw_quality = true

              match parse_quality(value) {
                Ok(parsed) => quality = parsed
                Err(error) => return Err(error)
              }
            } else {
              return Err(UnsupportedMediaParameter(parameter))
            }
          }
        }
      }

      Ok(MediaRange::{ major, minor, quality, })
    }
  }
}

///|
pub fn parse_accept(header : String) -> Result[Array[MediaRange], ParseError] {
  if trim_ows(header).length() == 0 {
    return Err(InvalidMediaRange(header))
  }

  let result : Array[MediaRange] = []

  for raw in split_ascii(header, ',') {
    match parse_media_range(raw) {
      Ok(range) => result.push(range)
      Err(error) => return Err(error)
    }
  }

  Ok(result)
}

///|
fn ascii_lower_code(unit : UInt16) -> Int {
  let code = unit.to_int()
  if code >= 65 && code <= 90 {
    code + 32
  } else {
    code
  }
}

///|
fn ascii_equal_ignore_case(left : String, right : String) -> Bool {
  if left.length() != right.length() {
    return false
  }

  for i = 0; i < left.length(); i = i + 1 {
    if ascii_lower_code(left.code_unit_at(i)) !=
      ascii_lower_code(right.code_unit_at(i)) {
      return false
    }
  }

  true
}

///|
/// Returns the structural specificity of this media range.
///
/// - `*/*` = 0
/// - `text/*` = 1
/// - `text/html` = 2
pub fn MediaRange::specificity(self : MediaRange) -> Int {
  if self.major == "*" {
    0
  } else if self.minor == "*" {
    1
  } else {
    2
  }
}

///|
/// Tests whether this media range structurally matches a concrete media type.
///
/// This method does not consider q-value. A range with q=0 may still
/// structurally match; acceptability is handled by selection logic.
pub fn MediaRange::matches(
  self : MediaRange,
  media_type : String,
) -> Result[Bool, ParseError] {
  let text = trim_ows(media_type)

  match parse_media_name(text) {
    Err(error) => Err(error)
    Ok((major, minor)) => {
      // Server offers must be concrete media types, not media ranges.
      if major == "*" || minor == "*" {
        return Err(InvalidMediaRange(media_type))
      }

      if self.major == "*" {
        Ok(true)
      } else if !ascii_equal_ignore_case(self.major, major) {
        Ok(false)
      } else if self.minor == "*" {
        Ok(true)
      } else {
        Ok(ascii_equal_ignore_case(self.minor, minor))
      }
    }
  }
}

///|
fn score_media_offer(
  ranges : Array[MediaRange],
  offer : String,
) -> Result[(Int, Int)?, ParseError] {
  let concrete = trim_ows(offer)

  match parse_media_name(concrete) {
    Err(error) => return Err(error)
    Ok((major, minor)) =>
      if major == "*" || minor == "*" {
        return Err(InvalidMediaRange(offer))
      }
  }

  let mut found = false
  let mut best_specificity = -1
  let mut best_quality = 0

  for range in ranges {
    match range.matches(concrete) {
      Err(error) => return Err(error)
      Ok(true) => {
        let specificity = range.specificity()

        // A more specific range determines the effective quality
        // for this concrete representation.
        if !found || specificity > best_specificity {
          found = true
          best_specificity = specificity
          best_quality = range.quality().thousandths()
        }
      }
      Ok(false) => ()
    }
  }

  if found {
    Ok(Some((best_quality, best_specificity)))
  } else {
    Ok(None)
  }
}

///|
/// Selects the preferred concrete media type from server-provided offers.
///
/// Selection policy:
/// 1. For each offer, the most specific matching Accept range determines
///    its effective q-value.
/// 2. q=0 makes that offer unacceptable.
/// 3. Higher effective q-value wins.
/// 4. If q-values tie, higher matching specificity wins.
/// 5. If both tie, the earlier server offer wins.
pub fn select_media_type(
  header : String,
  offers : Array[String],
) -> Result[String?, ParseError] {
  let ranges = match parse_accept(header) {
    Ok(parsed) => parsed
    Err(error) => return Err(error)
  }

  let mut selected : String? = None
  let mut selected_quality = -1
  let mut selected_specificity = -1

  for raw_offer in offers {
    let offer = trim_ows(raw_offer)

    if offer.length() == 0 {
      return Err(InvalidMediaRange(raw_offer))
    }

    match score_media_offer(ranges, offer) {
      Err(error) => return Err(error)
      Ok(None) => ()
      Ok(Some((quality, specificity))) =>
        if quality > 0 &&
          (
            selected is None ||
            quality > selected_quality ||
            (quality == selected_quality && specificity > selected_specificity)
          ) {
          selected = Some(offer)
          selected_quality = quality
          selected_specificity = specificity
        }
    }
  }

  Ok(selected)
}
