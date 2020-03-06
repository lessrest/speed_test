defmodule SpeedTest.Cookie do
  defstruct name: "",
            value: "",
            url: "",
            domain: "",
            path: "/",
            secure: false,
            httpOnly: true,
            sameSite: "None",
            expires: 2_147_483_647
end
