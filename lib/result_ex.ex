defmodule ResultEx do
  @moduledoc """
  ResultEx is a module for handling functions returning a `t:ResultEx.t/0`.
  This module is inspired by the f# Result module, and [Railway Oriented Programming](https://fsharpforfunandprofit.com/rop/) as explained by Scott Wlaschin.

  A result can be either the tuple {:ok, term} where term will be the expected return value of a function,
  or the tuple {:error, term} where term will be an explanation of what went wrong while executing a function.

  Using this module, it will be possible to combine functions that return a `t:ResultEx.t/0`, and functions that take the value contained by the ok variant.
  In the case one of the functions returns an error variant, subsequent functions expecting an ok result can be prevented from being executed.
  Also, functions can be connected that will only execute in the case of an error.

  ## Examples

      iex> defmodule ResultExExample do
      ...>
      ...>   def divide(0, _), do: {:error, :zero_division_exception}
      ...>   def divide(0.0, _), do: {:error, :zero_division_exception}
      ...>   def divide(x, y), do: ResultEx.return(x / y)
      ...>   def subtract(x, y), do: ResultEx.return(x - y)
      ...>
      ...> end
      ...>
      ...> ResultExExample.divide(4, 2)
      ...> |> ResultEx.bind(fn x -> ResultExExample.subtract(x, 2) end)
      {:ok, 0.0}
      iex> ResultExExample.divide(4, 2)
      ...> |> ResultEx.bind(fn x -> ResultExExample.subtract(x, 2) end)
      ...> |> ResultEx.bind(fn x -> ResultExExample.divide(x, 2) end)
      ...> |> ResultEx.bind(fn x -> ResultExExample.subtract(x, 2) end)
      {:error, :zero_division_exception}
      iex> ResultExExample.divide(0, 2)
      ...> |> ResultEx.or_else(2)
      2
      iex> ResultExExample.divide(0, 2)
      ...> |> ResultEx.or_else_with(fn _err -> {:ok, 0} end)
      {:ok, 0}

  """

  @type t ::
          {:ok, term}
          | {:error, term}

  @doc """
  Elevates a value to a `t:ResultEx.t/0` type.

  ## Examples

      iex> ResultEx.return(1)
      {:ok, 1}

  """
  @spec return(term) :: t
  def return(value), do: {:ok, value}

  @doc """
  Runs a function against the `t:ResultEx.t/0`s value.
  If the `t:ResultEx.t/0` is an error, the function will not be executed.

  ## Examples

      iex> result = {:ok, 1}
      ...> ResultEx.map(result, &(&1 + 1))
      {:ok, 2}

      iex> result = {:error, "Oops"}
      ...> ResultEx.map(result, &(&1 + 1))
      {:error, "Oops"}

  """
  @spec map(t, (term -> term)) :: t
  def map({:ok, value}, fun) do
    {:ok, fun.(value)}
  end

  def map(result, _), do: result

  @doc """
  Partially applies `ResultEx.map/2` with the passed function.
  """
  @spec map((term -> term)) :: (t -> t)
  def map(fun) do
    fn result -> map(result, fun) end
  end

  @doc """
  Executes or partially executes the function given as value of the first `t:ResultEx.t/0`,
  and applies it with the value of the second `t:ResultEx.t/0`.
  If the function has an arity greater than 1, the returned `t:ResultEx.t/0` value will be the function partially applied.
  (The function name is 'appl' rather than 'apply' to prevent import conflicts with 'Kernel.apply')

  ## Examples

      iex> value_result = {:ok, 1}
      ...> function_result = {:ok, fn value -> value + 1 end}
      ...> ResultEx.appl(function_result, value_result)
      {:ok, 2}

      iex> {:ok, fn value1, value2, value3 -> value1 + value2 + value3 end}
      ...> |> ResultEx.appl({:ok, 1})
      ...> |> ResultEx.appl({:ok, 2})
      ...> |> ResultEx.appl({:ok, 3})
      {:ok, 6}

      iex> {:error, "no such function"}
      ...> |> ResultEx.appl({:ok, 1})
      ...> |> ResultEx.appl({:ok, 1})
      ...> |> ResultEx.appl({:ok, 1})
      {:error, "no such function"}

      iex> {:ok, fn value1, value2, value3 -> value1 + value2 + value3 end}
      ...> |> ResultEx.appl({:ok, 1})
      ...> |> ResultEx.appl({:ok, 1})
      ...> |> ResultEx.appl({:error, "no such value"})
      {:error, "no such value"}

  """
  @spec appl(t, t) :: t
  def appl({:ok, fun}, {:ok, value}) do
    case :erlang.fun_info(fun, :arity) do
      {_, 0} ->
        {:error, "ResultEx.appl: arity error"}

      _ ->
        {:ok, curry(fun, value)}
    end
  end

  def appl({:error, _} = error, _), do: error

  def appl(_, {:error, _} = error), do: error

  @doc """
  Applies a function with the value of the `t:ResultEx.t/0`.
  The passed function is expected to return a `t:ResultEx.t/0`.
  This can be useful for chaining functions together that elevate values into `t:ResultEx.t/0`s.

  ## Examples

      iex> divide = fn
      ...>   0 -> {:error, "Zero division"}
      ...>   n -> {:ok, n / 2}
      ...> end
      ...> divide.(4)
      ...> |> ResultEx.bind(divide)
      {:ok, 1.0}

      iex> divide = fn
      ...>   0 -> {:error, "Zero division"}
      ...>   n -> {:ok, n / 2}
      ...> end
      ...> divide.(0)
      ...> |> ResultEx.bind(divide)
      {:error, "Zero division"}

  """
  @spec bind(t, (term -> t)) :: t
  def bind({:ok, value}, fun) do
    fun.(value)
  end

  def bind(result, _), do: result

  @doc """
  Partially applies `ResultEx.bind/2` with the passed function.
  """
  @spec bind((term -> t)) :: (t -> t)
  def bind(fun) do
    fn result -> bind(result, fun) end
  end

  @doc """
  Unwraps the `t:ResultEx.t/0` to return its value.
  Throws an error if the `t:ResultEx.t/0` is an error.

  ## Examples

      iex> ResultEx.return(5)
      ...> |> ResultEx.unwrap!()
      5

  """
  @spec unwrap!(t) :: term
  def unwrap!({:ok, value}), do: value

  def unwrap!({:error, error}), do: throw(error)

  @doc """
  Unwraps the `t:ResultEx.t/0` to return its value.
  The second argument will be a specific error message to throw when the `t:ResultEx.t/0` is an Error.

  ## Examples

      iex> ResultEx.return(5)
      ...> |> ResultEx.expect!("The value was not what was expected")
      5

  """
  @spec expect!(t, String.t()) :: term
  def expect!({:ok, value}, _), do: value

  def expect!(_, message), do: throw(message)

  @doc """
  Unwraps the `t:ResultEx.t/0` to return its value.
  If the `t:ResultEx.t/0` is an error, it will return the default value passed as second argument instead.

  ## Examples

      iex> ResultEx.return(5)
      ...> |> ResultEx.or_else(4)
      5

      iex> {:error, "Oops"}
      ...> |> ResultEx.or_else(4)
      4

  """
  @spec or_else(t, term) :: term
  def or_else({:ok, value}, _), do: value

  def or_else(_, default), do: default

  @doc """
  Unwraps the `t:ResultEx.t/0` to return its value.
  If the `t:ResultEx.t/0` is an error, the given function will be applied with the unwrapped error instead.

  ## Examples

      iex> ResultEx.return(5)
      ...> |> ResultEx.or_else_with(fn err -> IO.inspect(err) end)
      5

      iex> {:error, "Oops"}
      ...> |> ResultEx.or_else_with(fn err -> err <> "!" end)
      "Oops!"

  """
  @spec or_else_with(t, (term -> term)) :: term
  def or_else_with({:ok, value}, _), do: value

  def or_else_with({:error, error}, fun), do: fun.(error)

  @doc """
  Flatten nested `t:ResultEx.t/0`s into a single `t:ResultEx.t/0`.

  ## Examples

      iex> ResultEx.return(5)
      ...> |> ResultEx.return()
      ...> |> ResultEx.return()
      ...> |> ResultEx.flatten()
      {:ok, 5}

      iex> {:ok, {:ok, {:error, "Oops"}}}
      ...> |> ResultEx.flatten()
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
  Flattens an `t:Enum.t/0` of `t:ResultEx.t/0`s into a `t:ResultEx.t/0` of enumerables.

  ## Examples

      iex> [{:ok, 1}, {:ok, 2}, {:ok, 3}]
      ...> |> ResultEx.flatten_enum()
      {:ok, [1, 2, 3]}

      iex> [{:ok, 1}, {:error, "Oops"}, {:ok, 3}]
      ...> |> ResultEx.flatten_enum()
      {:error, "Oops"}

      iex> %{a: {:ok, 1}, b: {:ok, 2}, c: {:ok, 3}}
      ...> |> ResultEx.flatten_enum()
      {:ok, %{a: 1, b: 2, c: 3}}

      iex> %{a: {:ok, 1}, b: {:error, "Oops"}, c: {:ok, 3}}
      ...> |> ResultEx.flatten_enum()
      {:error, "Oops"}

  """
  @spec flatten_enum(Enum.t()) :: t
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

  def flatten_enum(_), do: {:error, "ResultEx.flatten_enum Unknown Type"}

  @doc """
  Converts the `t:ResultEx.t/0` to an Option.
  An Option is a {:some, term} tuple pair, or the :none atom.

  ## Examples

      iex> ResultEx.return(5)
      ...> |> ResultEx.to_option()
      {:some, 5}

      iex> {:error, "Oops"}
      ...> |> ResultEx.to_option()
      :none

  """
  @spec to_option(t) :: {:some, term} | :none
  def to_option({:ok, value}) do
    {:some, value}
  end

  def to_option({:error, _}), do: :none

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
