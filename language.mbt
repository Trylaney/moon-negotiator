///|
pub struct LanguageRange {
  pattern : String
  quality : Quality
} derive(Eq, Debug)

///|
pub fn LanguageRange::language_range(self : LanguageRange) -> String {
  self.pattern
}

///|
pub fn LanguageRange::quality(self : LanguageRange) -> Quality {
  self.quality
}

///|
pub fn LanguageRange::is_wildcard(self : LanguageRange) -> Bool {
  self.pattern == "*"
}

///|
fn is_ascii_alpha(unit : UInt16) -> Bool {
  let code = unit.to_int()
  (code >= 65 && code <= 90) || (code >= 97 && code <= 122)
}

///|
fn is_ascii_digit(unit : UInt16) -> Bool {
  let code = unit.to_int()
  code >= 48 && code <= 57
}

///|
fn is_ascii_alnum(unit : UInt16) -> Bool {
  is_ascii_alpha(unit) || is_ascii_digit(unit)
}

///|
fn valid_language_subtag(text : String, alpha_only : Bool) -> Bool {
  if text.length() == 0 || text.length() > 8 {
    return false
  }

  for i = 0; i < text.length(); i = i + 1 {
    let unit = text.code_unit_at(i)

    if alpha_only {
      if !is_ascii_alpha(unit) {
        return false
      }
    } else if !is_ascii_alnum(unit) {
      return false
    }
  }

  true
}

///|
/// Validates the Basic Language Range syntax used by RFC 4647.
///
/// This is deliberately not a complete BCP 47 semantic validator.
fn valid_basic_language_range(text : String) -> Bool {
  if text == "*" {
    return true
  }

  if text.length() == 0 {
    return false
  }

  let parts = split_ascii(text, '-')

  if parts.length() == 0 {
    return false
  }

  if !valid_language_subtag(parts[0], true) {
    return false
  }

  for i = 1; i < parts.length(); i = i + 1 {
    if !valid_language_subtag(parts[i], false) {
      return false
    }
  }

  true
}

///|
/// Performs lightweight structural validation for a concrete language tag.
///
/// It intentionally does not attempt registry-aware BCP 47 validation.
fn valid_language_tag_shape(text : String) -> Bool {
  text != "*" && valid_basic_language_range(text)
}

///|
fn parse_language_range(raw : String) -> Result[LanguageRange, ParseError] {
  let text = trim_ows(raw)

  if text.length() == 0 {
    return Err(InvalidLanguageRange(raw))
  }

  let parts = split_ascii(text, ';')
  let pattern = trim_ows(parts[0])

  if !valid_basic_language_range(pattern) {
    return Err(InvalidLanguageRange(raw))
  }

  let mut quality = Quality::{ value: 1000, }
  let mut saw_quality = false

  for i = 1; i < parts.length(); i = i + 1 {
    let parameter = trim_ows(parts[i])

    if parameter.length() == 0 {
      return Err(InvalidLanguageRange(raw))
    }

    match find_ascii(parameter, '=') {
      None => return Err(InvalidLanguageRange(raw))
      Some(equal) => {
        let name = trim_ows(parameter[0:equal].to_owned())
        let value = trim_ows(parameter[equal + 1:parameter.length()].to_owned())

        if name == "q" || name == "Q" {
          if saw_quality {
            return Err(InvalidLanguageRange(raw))
          }

          saw_quality = true

          match parse_quality(value) {
            Ok(parsed) => quality = parsed
            Err(error) => return Err(error)
          }
        } else {
          return Err(UnsupportedLanguageParameter(parameter))
        }
      }
    }
  }

  Ok(LanguageRange::{ pattern, quality, })
}

///|
/// Parses an Accept-Language field value using Basic Language Range syntax.
pub fn parse_accept_language(
  header : String,
) -> Result[Array[LanguageRange], ParseError] {
  if trim_ows(header).length() == 0 {
    return Ok([])
  }

  let result : Array[LanguageRange] = []

  for raw in split_ascii(header, ',') {
    match parse_language_range(raw) {
      Ok(range) => result.push(range)
      Err(error) => return Err(error)
    }
  }

  Ok(result)
}

///|
/// Returns true when this Basic Language Range matches a concrete tag.
///
/// Basic Filtering is case-insensitive and only matches in the
/// range -> tag direction.
pub fn LanguageRange::matches(
  self : LanguageRange,
  tag : String,
) -> Result[Bool, ParseError] {
  let concrete = trim_ows(tag)

  if !valid_language_tag_shape(concrete) {
    return Err(InvalidLanguageTag(tag))
  }

  if self.pattern == "*" {
    return Ok(true)
  }

  if self.pattern.length() > concrete.length() {
    return Ok(false)
  }

  for i = 0; i < self.pattern.length(); i = i + 1 {
    if ascii_lower_code(self.pattern.code_unit_at(i)) !=
      ascii_lower_code(concrete.code_unit_at(i)) {
      return Ok(false)
    }
  }

  if self.pattern.length() == concrete.length() {
    Ok(true)
  } else {
    Ok(concrete.code_unit_at(self.pattern.length()) == '-')
  }
}

///|
/// Larger values mean a more specific Basic Language Range.
///
/// `*` has specificity 0. Other ranges use their length so that
/// `en-US` outranks `en`.
pub fn LanguageRange::specificity(self : LanguageRange) -> Int {
  if self.pattern == "*" {
    0
  } else {
    self.pattern.length()
  }
}

///|
fn score_language_offer(
  ranges : Array[LanguageRange],
  offer : String,
) -> Result[(Int, Int)?, ParseError] {
  let tag = trim_ows(offer)

  if !valid_language_tag_shape(tag) {
    return Err(InvalidLanguageTag(offer))
  }

  let mut found = false
  let mut best_specificity = -1
  let mut best_quality = 0

  for range in ranges {
    match range.matches(tag) {
      Err(error) => return Err(error)
      Ok(false) => ()
      Ok(true) => {
        let specificity = range.specificity()

        // The longest matching language range determines
        // the quality of this concrete language tag.
        if !found || specificity > best_specificity {
          found = true
          best_specificity = specificity
          best_quality = range.quality().thousandths()
        }
      }
    }
  }

  if found {
    Ok(Some((best_quality, best_specificity)))
  } else {
    Ok(None)
  }
}

///|
/// Filters concrete server languages using RFC 4647 Basic Filtering.
///
/// Server offer order is preserved.
pub fn filter_languages(
  header : String,
  offers : Array[String],
) -> Result[Array[String], ParseError] {
  let ranges = match parse_accept_language(header) {
    Ok(parsed) => parsed
    Err(error) => return Err(error)
  }

  let result : Array[String] = []

  for raw_offer in offers {
    let offer = trim_ows(raw_offer)

    match score_language_offer(ranges, offer) {
      Err(error) => return Err(error)
      Ok(Some((quality, _))) => if quality > 0 { result.push(offer) }
      Ok(None) => ()
    }
  }

  Ok(result)
}

///|
/// Selects one concrete server language.
///
/// Policy:
/// 1. The longest matching Basic Language Range determines effective q.
/// 2. q=0 makes a language unacceptable.
/// 3. Higher effective q wins.
/// 4. Equal q prefers the more specific matching range.
/// 5. Complete ties preserve server offer order.
pub fn select_language(
  header : String,
  offers : Array[String],
) -> Result[String?, ParseError] {
  let ranges = match parse_accept_language(header) {
    Ok(parsed) => parsed
    Err(error) => return Err(error)
  }

  let mut selected : String? = None
  let mut selected_quality = -1
  let mut selected_specificity = -1

  for raw_offer in offers {
    let offer = trim_ows(raw_offer)

    match score_language_offer(ranges, offer) {
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
