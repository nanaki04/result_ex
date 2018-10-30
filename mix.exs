defmodule Result.MixProject do
  use Mix.Project

  @github "https://github.com/nanaki04/result_ex"

  def project do
    [
      app: :result,
      version: "0.1.0",
      description: "Module with helper functions for handling {:ok, value} or {:error, reason} return values",
      elixir: "~> 1.7",
      start_permanent: Mix.env() == :prod,
      deps: deps(),

      # Docs
      name: "Result",
      source_url: @github,
      docs: [
        main: "Result",
        extras: ["README.md"]
      ],

      # Hex Package
      package: package()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: []
    ]
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
      licences: ["MIT"],
      links: %{github: @github}
    ]
  end
end
