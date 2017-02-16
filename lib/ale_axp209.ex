defmodule AleAXP209 do
  @moduledoc """
  This module helps communicating with the AXP209 PMIC. This *Power Management IC* is mounted on the C.H.I.P. embedded computers.
  Make sure you start this Module as an Application to make it work. It will also monitor the state of the PMIC in background and
  allows to register for changes (not yet implemented!).

  Changes in the power state are reported to `Logger`.
  """

  use Application
  use GenServer
  use Bitwise, only_operators: true
  require Logger

  # Initial (and repeated) interval for checking power state
  @initial_interval 100
  @interval 5000

  # Below this voltage [mv] the battey is considered *disconnected*
  @bat_threshold 2200


  # ---------------------------------------------------------------------------
  # External API
  #

  @doc """
  Reads a register and returns the content as number.
  """
  def read_reg(addr) do
    GenServer.call __MODULE__, {:read_reg, addr}
  end

  @doc """
  Reads a pair of registers and returns the content as number. It uses 8 bits
  from the first register as MSB and the last 4 bits from the next register.
  This *encoding* is often used on this PMIC. Value returned as a number.
  """
  def read_dreg(addr) do
    GenServer.call __MODULE__, {:read_dreg, addr}
  end

  @doc """
  Reads the current charge current (current going *into* the battery) in mA.
  """
  def charge_current do
    GenServer.call __MODULE__, {:read_charge_current}
  end

  @doc """
  Reads the current discharge current (current comming *out of* the battery) in mA.
  """
  def discharge_current do
    GenServer.call __MODULE__, {:read_discharge_current}
  end

  @doc """
  Returns a map describing the state of the power system. The result is a map like this:

  ```
  %{
    battery: true,         # Battery is connected
    battery_voltage: 4161, # Battery voltage in mV
    charging: false,       # Not charging
    over_temp: false,      # Temperature of PMIC is good
    usb_power: true        # USB Power is connected
   }
  ```
  """
  def read_state do
    GenServer.call __MODULE__, {:read_state}
  end

  @doc """
  Sets the current input limit - how much power we're allowed to take from USB.
  """
  def setCurrentLimit(limit) do
    GenServer.cast __MODULE__, {:setLimit, limit}
  end


  # ---------------------------------------------------------------------------
  # Private helper functiond
  #

  # Read a single register and return the value as number
  defp read_reg(pid, addr) do
    << res :: size(8) >> = I2c.write_read(pid, <<addr>>, 1)
    res
  end

  # Reads a double-register as often used in this PMIC (8 bit MSB + 4 bit LSB)
  defp read_dreg(pid, addr) do
    << msb::size(8), _::size(4), lsb::size(4) >> = I2c.write_read(pid, <<addr>>, 2)
    msb <<< 4 ||| lsb
  end
  
  # Convert a 0/1 value to true/false or another pair of values
  defp to_bool(val, tr \\ true, fa \\ false) do
    case val do
      false -> fa
      0     -> fa
      _     -> tr
    end
  end

  # Read the first two state registers and pack results in a map
  # We need to fix some wrong values in here as C.H.I.P. reports a battery even
  # if there is none. The reported voltage is low so we use this to detect it.
  defp read_state(pid) do
    << _ac_pres :: size(1), _ac_inst :: size(1), _vbus_pres :: size(1), vbus_usea :: size(1),
       _vbus_ov :: size(1), _bat_dir :: size(1), _short     :: size(1), _boot_src :: size(1),
       ovr_temp :: size(1), charging :: size(1), battery    :: size(1), _ :: size(5) >> = I2c.write_read(pid, <<0x00>>, 2)
    voltage = round(1.1 * read_dreg pid, 0x78)
    %{
      usb_power: to_bool(vbus_usea),
      over_temp: to_bool(ovr_temp),
      charging: to_bool(charging),
      battery: to_bool(battery) && voltage >= @bat_threshold,
      battery_voltage: (if voltage >= @bat_threshold, do: voltage, else: :na)
    }
  end

  # Returns only the keys/values from *new* which are not equal the value on *old*
  defp return_changed(new, old) do
    new |> Enum.filter(fn {k,v} -> old[k] != v end)
  end

  # Report all items as changed
  defp report_changed(list) do
    list |> Enum.each( fn(pair) ->
      case pair do
        {:usb_power, val}   -> Logger.info "USB power #{to_bool val, "connected", "disconnected"}"
        {:battery,   val}   -> Logger.info "Battery #{to_bool val, "connected", "disconnected"}"
        {:charging,  val}   -> Logger.info "Battery charging #{to_bool val, "started", "stopped"}"
        {:over_temp, false} -> Logger.info "Power Management IC is at normal temperature"
        {:over_temp, true}  -> Logger.warn "Power Management IC is *TOO HOT*"
	_ ->  Logger.warn inspect pair
      end
    end )
  end


  # ---------------------------------------------------------------------------
  # GenServer callbacks and helper
  #

  # Starts a new process named __MODULE__ which will handle the PMIC.
  @doc false
  def start_link({bus, addr}=args) do
    Logger.info "Starting for bus: #{bus} on address 0x#{addr |> Integer.to_char_list(16)}"
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  # Opens the I2C connection to the PMIC and initializes state of the controller process.
  @doc false
  def init({bus, addr}) do
    {:ok, pid} = I2c.start_link(bus, addr)
    Process.link pid
    state = %{
      bus: bus,
      addr: addr,
      pid: pid,
      last: %{ },
      reported_voltage: 0
    }
    Process.send_after(self(), :timer, @initial_interval)
    {:ok, state}
  end

  def handle_call({:read_reg, addr}, _from, %{pid: pid} = state) do
    {:reply, read_reg(pid, addr), state}
  end

  def handle_call({:read_dreg, addr}, _from, %{pid: pid} = state) do
    {:reply, read_dreg(pid, addr), state}
  end

  def handle_call({:read_state}, _from, %{pid: pid} = state) do
    {:reply, read_state(pid), state}
  end

  def handle_call({:read_discharge_current}, _from, %{pid: pid} = state) do
    {:reply, round(0.5 * read_dreg pid, 0x7C), state}
  end

  def handle_call({:read_charge_current}, _from, %{pid: pid} = state) do
    {:reply, round(0.5 * read_dreg pid, 0x7A), state}
  end

  def handle_cast({:setLimit, mA}, %{pid: pid} = state) do
    val = cond do
      mA >= 1000 -> 0x63
      mA >=  900 -> 0x60
      mA >=  500 -> 0x61
      mA >=  100 -> 0x62
    end

    :ok = I2c.write(pid, <<0x30, val>>)
    {:noreply, state}
  end

  # Timer handler - checks the state periodically and send notifications to
  # processes if the state changes
  def handle_info(:timer, %{pid: pid, last: last, reported_voltage: reported} = state) do
    Logger.debug "Checking power state..."
    res = %{battery: battery, battery_voltage: voltage} = read_state(pid)
    res |> Map.delete(:battery_voltage) |> return_changed(last) |> report_changed

    Process.send_after(self(), :timer, @interval)

    # Report battery voltage if present and changed more than 50mV
    if battery && abs(voltage - reported) > 50 do
      Logger.info "Battery voltage is #{voltage}mV - Discharging at #{round(0.5 * read_dreg pid, 0x7C)}mA"
      {:noreply, %{state | last: Map.delete(res, :battery_voltage), reported_voltage: voltage}}
    else
      {:noreply, %{state | last: Map.delete(res, :battery_voltage)}}
    end
  end


  # ---------------------------------------------------------------------------
  # Application callbacks
  #

  # Used to bring up the PMIC *application*.
  @doc false
  def start(_type, args) do
    import Supervisor.Spec, warn: false

    Logger.info "Application supervisor is starting up..."
    children = [
      worker(__MODULE__, [args])
    ]
    Supervisor.start_link(children, [strategy: :one_for_one])
  end

end
