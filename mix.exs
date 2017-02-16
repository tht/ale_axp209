defmodule AleAXP209.Mixfile do
  use Mix.Project

  def project do
    [app: :ale_axp209,
     version: "0.2.0",
     elixir: "~> 1.4",
     name: "ale_axp209",
     descriptio: description(),
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps(),
     docs: docs()]
  end

  # Configuration for the OTP application
  def application do
    [
      extra_applications: [:logger],
      mod: {AleAXP209, {"i2c-0", 0x34}}
    ]
  end

  defp description do
    """
    AXP209 PMIC interface for Elixir (C.H.I.P. Power Management IC)
    """
  end

  # Dependencies can be Hex packages:
  defp deps do
    [
      {:elixir_ale, "~> 0.5.7"},
      {:ex_doc, "~> 0.11", only: :dev},
      {:remix, "~> 0.0.1", only: :dev}
    ]
  end

  defp docs do
    [ 
      extras: ["README.md"]
    ]
  end
end
