defmodule ResultEx.MixProject do
  use Mix.Project

  @github "https://github.com/nanaki04/result_ex"

  def project do
    [
      app: :result_ex,
      version: "0.1.0",
      description:
        "Module with helper functions for handling {:ok, value} or {:error, reason} return values",
      elixir: "~> 1.7",
      start_permanent: Mix.env() == :prod,
      deps: deps(),

      # Docs
      name: "ResultEx",
      source_url: @github,
      docs: [
        main: "ResultEx",
        extras: ["README.md"]
      ],

      # Hex Package
      package: package()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    []
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:dialyxir, "~> 0.5", only: [:dev], runtime: false},
      {:ex_doc, "~> 0.16", only: [:dev], runtime: false}
    ]
  end

  defp package do
    [
      licenses: ["MIT"],
      maintainers: ["Robert Jan Zwetsloot"],
      links: %{github: @github}
    ]
  end
end
