defmodule SpeedTest.Page.Registry do
  @moduledoc ~S"""
  Registry that contains state on running pages.
  """

  @doc ~S"""
  Given a page with an id, will register the current process under that id.
  """
  @spec register(atom | %{id: any}) :: {:error, {:already_registered, pid}} | {:ok, pid}
  def register(page) do
    Registry.register(PageRegistry, page.id, page)
  end

  @doc ~S"""
  Looks up a given page and returns the associated process.
  """
  @spec lookup(atom | %{id: any}) :: {:error, :not_registered} | {:ok, {pid, any}}
  def lookup(page) do
    case Registry.lookup(PageRegistry, page.id) do
      [] -> {:error, :not_registered}
      [page] -> {:ok, page}
    end
  end
end
