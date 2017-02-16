# AXP209 PMIC Interface for Elixir

`ale_axp209` provides an interface to the AXP209 PMIC which is mounted on C.H.I.P. baords and maybe others. The library provides an easy to use interface to query different states such as the connected power source, the battery voltage and charging/discharging currents. The PMIC is monitored and changes are reported using `Logger`.

## Installation

Module is available in [Hex](https://hex.pm/packages/ale_axp209), the package can be installed
by adding `ale_axp209` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [{:ale_axp209, "~> 0.2.0"}]
end
```

Documentation is published online on [HexDocs](https://hexdocs.pm/ale_axp209) or available as download on [Hex](https://hex.pm/packages/ale_axp209).

