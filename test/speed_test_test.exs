defmodule SpeedTestTest do
  use ExUnit.Case, async: true
  doctest SpeedTest

  import SpeedTest

  setup do
    page = launch()
    dimensions(page, %{width: 1920, height: 1080})

    [page: page]
  end

  test "opens a new page" do
    page = launch()
    assert is_pid(page)
  end

  test "navigates to a website", %{page: page} do
    assert :ok == goto(page, "/")
  end

  test "takes screenshots", %{page: page} do
    goto(page, "/")
    {:ok, png} = screenshot(page)

    assert png |> is_binary()
    assert String.length(png) > 0
  end

  test "returns pdfs", %{page: page} do
    goto(page, "/")
    {:ok, pdf} = pdf(page)

    assert pdf |> is_binary()
    assert String.length(pdf) > 0
  end

  test "fills in inputs", %{page: page} do
    goto(page, "/")

    {:ok, email_input} = page |> get("[data-test=login_email]")
    :ok = type(page, email_input, "testing@test.com")

    assert {:ok, "testing@test.com"} == value(page, email_input)
  end

  test "clears inputs", %{page: page} do
    goto(page, "/")

    {:ok, email_input} = page |> get("[data-test=login_email]")
    :ok = type(page, email_input, "testing@test.com")

    assert {:ok, "testing@test.com"} == value(page, email_input)

    :ok = page |> clear(email_input)

    assert {:ok, ""} == value(page, email_input)
  end

  test "gets arbitrary element properties", %{page: page} do
    goto(page, "/")

    {:ok, email_input} = page |> get("[data-test=login_email]")
    assert property(page, email_input, "type") == {:ok, "email"}
  end

  test "gets element attributes as map", %{page: page} do
    goto(page, "/")

    {:ok, email_input} = page |> get("[data-test=login_email]")
    {:ok, attributes} = page |> attributes(email_input)
    assert attributes == %{"data-test" => "login_email", "name" => "test", "type" => "email"}
  end

  test "gets a single attribute for an element", %{page: page} do
    goto(page, "/")

    {:ok, email_input} = page |> get("[data-test=login_email]")
    {:ok, attribute} = page |> attribute(email_input, "name")
    assert attribute == "test"
  end

  test "clicks on elements", %{page: page} do
    goto(page, "/")

    {:ok, submit_button} = page |> get("button")
    :ok = page |> click(submit_button)

    {:ok, test_output} = page |> get("#test-output")

    assert property(page, test_output, "innerHTML") == {:ok, "Dummy Text"}
  end
end
