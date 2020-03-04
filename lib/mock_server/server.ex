defmodule Test.Support.MockServer do
  use Plug.Router

  plug(:match)
  plug(:dispatch)

  get "/" do
    conn
    |> put_resp_content_type("text/html")
    |> send_resp(
      200,
      "<html><head></head><body><h1>I am a website</h1><input name=\"test\" data-test=\"login_email\" /></body></html>"
    )
  end

  match _ do
    conn
    |> put_resp_content_type("text/html")
    |> send_resp(404, "<html><head></head><body><h1>Not found.</h1></body></html>")
  end
end
