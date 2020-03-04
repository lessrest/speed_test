{:ok, _started} = Application.ensure_all_started(:speed_test)

page = SpeedTest.launch()

SpeedTest.goto(page, "https://google.com") |> IO.inspect()

SpeedTest.pdf(page, %{path: "./stuff.pdf"}) |> IO.inspect()

SpeedTest.screenshot(page, %{path: "./stuff.png"}) |> IO.inspect()

SpeedTest.close(page)
