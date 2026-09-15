///|
fn main {
  let header = "br;q=1, gzip;q=0.8, identity;q=0.1"
  let offers = ["gzip", "br", "identity"]

  match @negotiator.select_encoding(header, offers) {
    Ok(Some(selected)) => println("Selected encoding: \{selected}")
    Ok(None) => println("No acceptable encoding")
    Err(_) => println("Invalid Accept-Encoding header or server offer")
  }
}
