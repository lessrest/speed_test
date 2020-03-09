defmodule SpeedTest.Cookie do
  @moduledoc """
  Struct that represents HTTP cookies

  ### Examples

        iex> %SpeedTest.Cookie{domain: "localhost", name: "testing", value: "123"}
  """
  defstruct name: "",
            value: "",
            url: "",
            domain: "",
            path: "/",
            secure: false,
            http_only: false,
            same_site: "None",
            expires: 2_147_483_647
end
