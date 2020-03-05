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

    {:ok, email_input} = page |> SpeedTest.get("[data-test=login_email]")
    :ok = SpeedTest.type(page, email_input, "testing@test.com")

    assert "testing@test.com" == SpeedTest.value(page, email_input)
  end

  test "gets arbitrary element properties", %{page: page} do
    SpeedTest.goto(page, @dummy_site)

    {:ok, email_input} = page |> SpeedTest.get("[data-test=login_email]")
    assert SpeedTest.property(page, email_input, "type") == "email"
  end

  test "gets element attributes as map", %{page: page} do
    SpeedTest.goto(page, @dummy_site)

    {:ok, email_input} = page |> SpeedTest.get("[data-test=login_email]")
    {:ok, attributes} = page |> SpeedTest.attributes(email_input)
    assert attributes == %{"data-test" => "login_email", "name" => "test", "type" => "email"}
  end

  test "gets a single attribute for an element", %{page: page} do
    SpeedTest.goto(page, @dummy_site)

    {:ok, email_input} = page |> SpeedTest.get("[data-test=login_email]")
    {:ok, attribute} = page |> SpeedTest.attribute(email_input, "name")
    assert attribute == "test"
  end

  test "clicks on elements", %{page: page} do
    SpeedTest.goto(page, @dummy_site)

    {:ok, submit_button} = page |> SpeedTest.get("button")
    :ok = page |> SpeedTest.click(submit_button)

    {:ok, test_output} = page |> SpeedTest.get("#test-output")

    assert SpeedTest.property(page, test_output, "innerHTML") == "Dummy Text"
  end
end
