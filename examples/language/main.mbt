///|
fn main {
  let header = "zh-CN, zh;q=0.9, en;q=0.8"
  let offers = ["en-US", "zh-CN", "ja-JP"]

  match @negotiator.select_language(header, offers) {
    Ok(Some(selected)) => println("Selected language: \{selected}")
    Ok(None) => println("No acceptable language")
    Err(_) => println("Invalid Accept-Language header or server offer")
  }
}
