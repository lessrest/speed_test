defmodule SpeedTest.Page.Registry do
  @moduledoc ~S"""
  Registry that contains state on running pages.
  """

  def register(page) do
    Registry.register(PageRegistry, page.id, page)
  end

  def lookup(page) do
    case Registry.lookup(PageRegistry, page.id) do
      [] -> {:error, :not_registered}
      [page] -> {:ok, page}
    end
  end
end
