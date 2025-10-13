import gleam/erlang/process
import mist
import wisp
import wisp/wisp_mist

type Context {
  Context(static_directory: String)
}

pub fn main() {
  wisp.configure_logger()
  let secret_key_base = wisp.random_string(64)

  // A context is constructed holding the static directory path.
  let ctx = Context(static_directory: "build/dev/docs/jrstrunk")

  // The handle_request function is partially applied with the context to make
  // the request handler function that only takes a request.
  let handler = handle_request(_, ctx)

  let assert Ok(_) =
    wisp_mist.handler(handler, secret_key_base)
    |> mist.new
    |> mist.port(8000)
    |> mist.start

  process.sleep_forever()
}

fn handle_request(req, ctx: Context) {
  let req = wisp.method_override(req)
  use <- wisp.log_request(req)
  use <- wisp.rescue_crashes
  use req <- wisp.handle_head(req)
  use req <- wisp.csrf_known_header_protection(req)
  use <- wisp.serve_static(req, under: "/static", from: ctx.static_directory)
  todo
}
