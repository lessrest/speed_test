defmodule SpeedTestTest do
  use ExUnit.Case, async: true
  doctest SpeedTest

  @dummy_site "http://localhost:8081/"

  setup do
    page = SpeedTest.launch()
    SpeedTest.dimensions(page, %{width: 1920, height: 1080})

    [page: page]
  end

  test "opens a new page" do
    page = SpeedTest.launch()
    assert is_pid(page)
  end

  test "navigates to a website", %{page: page} do
    assert :ok == SpeedTest.goto(page, @dummy_site)
  end

  test "takes screenshots", %{page: page} do
    SpeedTest.goto(page, @dummy_site)
    png = SpeedTest.screenshot(page)

    assert png |> is_binary()
    assert String.length(png) > 0
  end

  test "returns pdfs", %{page: page} do
    SpeedTest.goto(page, @dummy_site)
    png = SpeedTest.pdf(page)

    assert png |> is_binary()
    assert String.length(png) > 0
  end

  test "fills in inputs", %{page: page} do
    SpeedTest.goto(page, @dummy_site)

    {:ok, login} = page |> SpeedTest.get("[data-test=login_email]")
    :ok = SpeedTest.type(page, login, "testing@test.com")

    assert "testing@test.com" == SpeedTest.get_attribute(page, login, "value")
  end
end
