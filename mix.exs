defmodule TypedStructApiSpex.MixProject do
  use Mix.Project

  def project do
    [
      app: :typed_struct_api_spex,
      version: "0.1.0",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      consolidate_protocols: Mix.env() != :test,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:typed_struct, "~> 0.3"},
      {:open_api_spex, "~> 3.17"},
      {:jason, "~> 1.0", only: [:dev, :test]},
      {:credo, "~> 1.7", only: :dev, runtime: false}
    ]
  end
end
