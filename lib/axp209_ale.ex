defmodule Axp209Ale do
  @moduledoc """
  Documentation for Axp209Ale.
  """

  use Application
  require Logger

  @doc """
  Hello world.

  ## Examples

      iex> Axp209Ale.hello
      :world

  """
  def read_reg(addr) do
    GenServer.call __MODULE__, {:read_reg, addr}
  end

  def read_dreg(addr) do
    GenServer.call __MODULE__, {:read_dreg, addr}
  end

  def charge_current do
    GenServer.call __MODULE__, {:read_charge_current}
  end

  def discharge_current do
    GenServer.call __MODULE__, {:read_discharge_current}
  end

  def read_state do
    GenServer.call __MODULE__, {:read_state}
  end

  def setCurrentLimit(limit) do
    GenServer.cast __MODULE__, {:setLimit, limit}
  end



  def start(_type, args) do
    import Supervisor.Spec, warn: false

    Logger.info "Application supervisor is starting up..."
    children = [
      worker(Axp209Ale.Worker, [args])
    ]
    Supervisor.start_link(children, [strategy: :one_for_one])
  end
end
