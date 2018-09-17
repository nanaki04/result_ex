defmodule Result do

  @moduledoc """
  Library containing helper functions for the result monad.
  """

  @type t :: {:ok, term}
    | {:error, term}

  @doc """
  Elevates a value to a Result type.

  ## Examples

      iex> Result.return(1)
      {:ok, 1}

  """
  @spec return(term) :: t
  def return(value), do: {:ok, value}

  @doc """
  Runs a function against the Results value.
  If the Result is an error, the function will not be executed.

  ## Examples

      iex> result = {:ok, 1}
      ...> Result.map(result, &(&1 + 1))
      {:ok, 2}

      iex> result = {:error, "Oops"}
      ...> Result.map(result, &(&1 + 1))
      {:error, "Oops"}

  """
  @spec map(t, fun) :: t
  def map({:ok, value}, fun) do
    {:ok, fun.(value)}
  end

  def map(error, _), do: error

  @doc """
  Executes or partially executes the function given as value of the first Result,
  and applies it with the value of the second Result.
  If the function has an arity greater than 1, the returned Result value will be the function partially applied.

  ## Examples

      iex> value_result = {:ok, 1}
      ...> function_result = {:ok, fn value -> value + 1 end}
      ...> Result.appl(function_result, value_result)
      {:ok, 2}

      iex> {:ok, fn value1, value2, value3 -> value1 + value2 + value3 end}
      ...> |> Result.appl({:ok, 1})
      ...> |> Result.appl({:ok, 2})
      ...> |> Result.appl({:ok, 3})
      {:ok, 6}

      iex> {:error, "no such function"}
      ...> |> Result.appl({:ok, 1})
      ...> |> Result.appl({:ok, 1})
      ...> |> Result.appl({:ok, 1})
      {:error, "no such function"}

      iex> {:ok, fn value1, value2, value3 -> value1 + value2 + value3 end}
      ...> |> Result.appl({:ok, 1})
      ...> |> Result.appl({:ok, 1})
      ...> |> Result.appl({:error, "no such value"})
      {:error, "no such value"}

  """
  @spec appl(t, t) :: t
  def appl({:ok, fun}, {:ok, value}) do
    case :erlang.fun_info(fun, :arity) do
      {_, 0} ->
        {:error, "Result.appl: arity error"}
      _ ->
        {:ok, curry(fun, value)}
    end
  end

  def appl({:error, _} = error, _), do: error

  def appl(_, {:error, _} = error), do: error

  @doc """
  Applies a function with the value of the Result.
  The passed function is expected to return a Result.
  This can be useful for chaining functions that elevate values into results together.

  ## Examples

      iex> divide = fn
      ...>   0 -> {:error, "Zero division"}
      ...>   n -> {:ok, n / 2}
      ...> end
      ...> divide.(4)
      ...> |> Result.bind(divide)
      {:ok, 1.0}

      iex> divide = fn
      ...>   0 -> {:error, "Zero division"}
      ...>   n -> {:ok, n / 2}
      ...> end
      ...> divide.(0)
      ...> |> Result.bind(divide)
      {:error, "Zero division"}

  """
  @spec bind(t, (term -> t)) :: t
  def bind({:ok, value}, fun) do
    fun.(value)
  end

  def bind(error, _), do: error

  @doc """
  Unwraps the Result to return its value.
  Throws an error if the Result is an error.

  ## Examples

      iex> Result.return(5)
      ...> |> Result.unwrap!()
      5

  """
  @spec unwrap!(t) :: term
  def unwrap!({:ok, value}), do: value

  def unwrap!({:error, error}), do: throw(error)

  @doc """
  Unwraps the Result to return its value.
  The second argument will be a specific error message to throw when the result is an Error.

  ## Examples

      iex> Result.return(5)
      ...> |> Result.expect!("The value was not what was expected")
      5

  """
  @spec expect!(t, String.t) :: term
  def expect!({:ok, value}, _), do: value

  def expect!(_, message), do: throw(message)

  @doc """
  Unwraps the Result to return its value.
  If the Result is an error, it will return the default value passed as second argument instead.

  ## Examples

      iex> Result.return(5)
      ...> |> Result.or_else(4)
      5

      iex> {:error, "Oops"}
      ...> |> Result.or_else(4)
      4

  """
  @spec or_else(t, term) :: term
  def or_else({:ok, value}, _), do: value

  def or_else(_, default), do: default

  @doc """
  Unwraps the Result to return its value.
  If the Result is an error, the given function will be applied with the unwrapped error instead.

  ## Examples

      iex> Result.return(5)
      ...> |> Result.or_else_with(fn err -> IO.inspect(err) end)
      5

      iex> {:error, "Oops"}
      ...> |> Result.or_else_with(fn err -> err <> "!" end)
      "Oops!"

  """
  @spec or_else_with(t, fun) :: term
  def or_else_with({:ok, value}, _), do: value

  def or_else_with({:error, error}, fun), do: fun.(error)

  @doc """
  Flatten nested Results into one Result.

  ## Examples

      iex> Result.return(5)
      ...> |> Result.return()
      ...> |> Result.return()
      ...> |> Result.flatten()
      {:ok, 5}

      iex> {:ok, {:ok, {:error, "Oops"}}}
      ...> |> Result.flatten()
      {:error, "Oops"}

  """
  @spec flatten(t) :: t
  def flatten({:ok, {:ok, _} = inner_result}) do
    flatten(inner_result)
  end

  def flatten({:ok, {:error, _} = error}), do: error

  def flatten({:ok, _} = result), do: result

  def flatten({:error, _} = error), do: error

  @doc """
  Flattens an enumerable of Results into a Result of enumerables.

  ## Examples

      iex> [{:ok, 1}, {:ok, 2}, {:ok, 3}]
      ...> |> Result.flatten_enum()
      {:ok, [1, 2, 3]}

      iex> [{:ok, 1}, {:error, "Oops"}, {:ok, 3}]
      ...> |> Result.flatten_enum()
      {:error, "Oops"}

      iex> %{a: {:ok, 1}, b: {:ok, 2}, c: {:ok, 3}}
      ...> |> Result.flatten_enum()
      {:ok, %{a: 1, b: 2, c: 3}}

      iex> %{a: {:ok, 1}, b: {:error, "Oops"}, c: {:ok, 3}}
      ...> |> Result.flatten_enum()
      {:error, "Oops"}

  """
  @spec flatten_enum(Enum.t) :: t
  def flatten_enum(%{} = enum) do
    Enum.reduce(enum, {:ok, %{}}, fn
      {key, {:ok, value}}, {:ok, result} ->
        Map.put(result, key, value)
        |> return
      _, {:error, _} = error ->
        error
      {_, {:error, _} = error}, _ ->
        error
    end)
  end

  def flatten_enum(enum) when is_list(enum) do
    Enum.reduce(enum, {:ok, []}, fn
      {:ok, value}, {:ok, result} ->
        {:ok, [value | result]}
      _, {:error, _} = error ->
        error
      {:error, _} = error, _ ->
        error
    end)
    |> map(&Enum.reverse/1)
  end

  def flatten_enum(_), do: {:error, "Result.flatten_enum Unknown Type"}

  @spec curry(fun, term) :: term
  defp curry(fun, arg1), do: apply_curry(fun, [arg1])

  @spec apply_curry(fun, [term]) :: term
  defp apply_curry(fun, args) do
    {_, arity} = :erlang.fun_info(fun, :arity)
    if arity == length(args) do
      apply(fun, Enum.reverse(args))
    else
      fn arg -> apply_curry(fun, [arg | args]) end
    end
  end

end
