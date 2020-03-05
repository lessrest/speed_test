defmodule SpeedTest.Cookie do
  defstruct name: "",
            value: "",
            url: "",
            domain: "",
            path: "/",
            secure: true,
            httpOnly: true,
            sameSite: "Lax"
end
