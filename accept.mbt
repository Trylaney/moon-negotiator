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
