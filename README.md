# axp209_ale - AXP209 PMIC Interface for Elixir

`axp209_ale` provides an interface to the AXP209 PMIC which is mounted on C.H.I.P. baords and maybe others. The library provides an easy to use interface to query different states such as the connected power source, the battery voltage and charging/discharging currents. The PMIC is monitored and changes are reported using `Logger`.

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `axp209_ale` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [{:axp209_ale, "~> 0.2.0"}]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at [https://hexdocs.pm/axp209_ale](https://hexdocs.pm/axp209_ale).

