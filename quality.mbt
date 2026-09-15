///|
pub struct Quality {
  value : Int
} derive(Eq, Compare, Debug)

///|
pub(all) suberror ParseError {
  InvalidQuality(String)
  InvalidMediaRange(String)
  UnsupportedMediaParameter(String)
} derive(Eq, Debug)

///|
pub fn Quality::thousandths(self : Quality) -> Int {
  self.value
}

///|
fn digit_value(unit : UInt16) -> Int? {
  if unit >= '0' && unit <= '9' {
    Some(unit.to_int() - 48)
  } else {
    None
  }
}

///|
pub fn parse_quality(text : String) -> Result[Quality, ParseError] {
  let len = text.length()

  if len == 0 || len > 5 {
    return Err(InvalidQuality(text))
  }

  let first = text.code_unit_at(0)

  if first != '0' && first != '1' {
    return Err(InvalidQuality(text))
  }

  if len == 1 {
    if first == '1' {
      return Ok(Quality::{ value: 1000, })
    } else {
      return Ok(Quality::{ value: 0, })
    }
  }

  if text.code_unit_at(1) != '.' {
    return Err(InvalidQuality(text))
  }

  let mut fraction = 0
  let mut scale = 100

  for i = 2; i < len; i = i + 1 {
    match digit_value(text.code_unit_at(i)) {
      Some(digit) => {
        fraction = fraction + digit * scale
        scale = scale / 10
      }
      None => return Err(InvalidQuality(text))
    }
  }

  if first == '1' {
    if fraction != 0 {
      Err(InvalidQuality(text))
    } else {
      Ok(Quality::{ value: 1000, })
    }
  } else {
    Ok(Quality::{ value: fraction, })
  }
}
