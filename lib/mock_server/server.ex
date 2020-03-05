defmodule Test.Support.MockServer do
  use Plug.Router

  plug(:match)
  plug(:dispatch)

  get "/" do
    conn
    |> put_resp_content_type("text/html")
    |> send_resp(
      200,
      ~S"""
      <html>
        <head>
          <title>Dummy Site</title>
        </head>

        <body>
          <h1>I am a website</h1>
          <input type="email" name="test" data-test="login_email" />
          <button>Submit</button>
          <p id="test-output"></p>
          <p id="text-output"></p>

          <script>
            const input = document.querySelector("input");
            const button = document.querySelector("button");
            const complexOutput = document.getElementById("text-output");
            const output = document.getElementById("test-output");

            button.addEventListener("click", () => {
              output.innerHTML = "Dummy Text";
            });
          </script>
        </body>
      </html>
      """
    )
  end

  match _ do
    conn
    |> put_resp_content_type("text/html")
    |> send_resp(404, "<html><head></head><body><h1>Not found.</h1></body></html>")
  end
end
