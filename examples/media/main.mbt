///|
fn main {
  let header = "text/*;q=0.8, application/json;q=0.9"
  let offers = ["text/html", "application/json"]

  match @negotiator.select_media_type(header, offers) {
    Ok(Some(selected)) => println("Selected media type: \{selected}")
    Ok(None) => println("No acceptable media type")
    Err(_) => println("Invalid Accept header or server offer")
  }
}
