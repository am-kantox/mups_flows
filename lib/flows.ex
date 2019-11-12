defmodule Flows do
  @moduledoc """
  Comparison of different approaches for enum / streaming / parallel processing.
  """

  defmodule FizzBuzz do
    @moduledoc """

    Module with different `FizzBuzz` implementations

    ## Examples

        iex> Flows.FizzBuzz.map(:enum, 1..6)
        [{1, "Crap"}, {2, "Crap"}, {3, "Buzz"}, {4, "Crap"}, {5, "Fizz"}, {6, "Buzz"}]

        iex> Flows.FizzBuzz.map(:stream, 1..6)
        [{1, "Crap"}, {2, "Crap"}, {3, "Buzz"}, {4, "Crap"}, {5, "Fizz"}, {6, "Buzz"}]

        iex> Flows.FizzBuzz.map(:flow, 1..6)
        [{1, "Crap"}, {2, "Crap"}, {3, "Buzz"}, {4, "Crap"}, {5, "Fizz"}, {6, "Buzz"}]

        iex> Flows.FizzBuzz.reduce(:enum, 1..6)
        %{"Buzz" => [3, 6], "Crap" => [1, 2, 4], "Fizz" => [5]}

        iex> Flows.FizzBuzz.reduce(:flow, 1..6)
        %{"Buzz" => [3, 6], "Crap" => [1, 2, 4], "Fizz" => [5]}
    """

    @spec map(
            kind :: :enum | :stream | :flow,
            enumerable :: Enumerable.t(),
            (non_neg_integer() -> binary())
          ) :: Enumerable.t()
    def map(kind, enumerable, mapper \\ &mapper/1)

    @doc """
    `FizzBuzz` with a simple `Enum.map/2`, returning a list of `{input, result}` tuples.

        iex> Flows.FizzBuzz.map(:enum, 1..6)
        [{1, "Crap"}, {2, "Crap"}, {3, "Buzz"}, {4, "Crap"}, {5, "Fizz"}, {6, "Buzz"}]
    """
    def map(:enum, enumerable, mapper),
      do: Enum.map(enumerable, mapper)

    @doc """
    `FizzBuzz` using `Stream.map/2`, returning a list of `{input, result}` tuples.

        iex> Flows.FizzBuzz.map(:stream, 1..6)
        [{1, "Crap"}, {2, "Crap"}, {3, "Buzz"}, {4, "Crap"}, {5, "Fizz"}, {6, "Buzz"}]
    """
    def map(:stream, enumerable, mapper) do
      enumerable
      |> Stream.map(mapper)
      |> Enum.to_list()
    end

    @doc """
    `FizzBuzz` using `Flow`, returning a list of `{input, result}` tuples.

        iex> Flows.FizzBuzz.map(:flow, 1..6)
        [{1, "Crap"}, {2, "Crap"}, {3, "Buzz"}, {4, "Crap"}, {5, "Fizz"}, {6, "Buzz"}]
    """
    def map(:flow, enumerable, mapper) do
      # join_window = Flow.Window.global() |> Flow.Window.trigger_periodically(10, :second)
      count = Enum.count(enumerable)
      key = &div(&1, 8)

      enumerable
      |> Flow.from_enumerable()
      |> Flow.partition(key: key)
      |> Flow.reduce(fn -> [] end, &[mapper.(&1) | &2])
      |> Flow.take_sort(count, fn {i1, _}, {i2, _} -> i1 <= i2 end)
      |> Enum.at(0)
    end

    @spec reduce(
            kind :: :enum | :flow,
            enumerable :: Enumerable.t(),
            (non_neg_integer() -> binary())
          ) :: Enumerable.t()
    def reduce(kind, enumerable, mapper \\ &mapper/1)

    @doc """
    `FizzBuzz` with a simple `Enum.reduce/3`, returning a map of `%{result => [input]}`.

        iex> Flows.FizzBuzz.reduce(:enum, 1..6)
        %{"Buzz" => [3, 6], "Crap" => [1, 2, 4], "Fizz" => [5]}
    """
    def reduce(:enum, enumerable, mapper) do
      enumerable
      |> Enum.reduce(%{}, fn i, acc ->
        Map.update(
          acc,
          elem(mapper(i), 1),
          [elem(mapper.(i), 0)],
          &[elem(mapper.(i), 0) | &1]
        )
      end)
      |> Enum.into(%{}, fn {k, v} -> {k, :lists.reverse(v)} end)
    end

    @doc """
    `FizzBuzz` with `Flow`, returning a map of `%{result => [input]}`.

        iex> Flows.FizzBuzz.reduce(:flow, 1..6)
        %{"Buzz" => [3, 6], "Crap" => [1, 2, 4], "Fizz" => [5]}
    """
    def reduce(:flow, enumerable, mapper) do
      lists =
        enumerable
        |> Flow.from_enumerable()
        |> Flow.partition(key: &elem(mapper(&1), 1))
        |> Flow.reduce(fn -> [] end, &[elem(mapper.(&1), 0) | &2])
        |> Flow.emit(:state)
        |> Enum.to_list()

      for [h | _] = list <- lists, into: %{}, do: {elem(mapper.(h), 1), Enum.reverse(list)}
    end

    @doc "A helper to make benchmarks, exposes a mapper that delays before return"
    @spec mapper_with_delay(i :: non_neg_integer(), delay :: non_neg_integer()) :: binary()
    def mapper_with_delay(i, delay) do
      Process.sleep(delay)
      mapper(i)
    end

    @spec mapper(i :: non_neg_integer()) :: binary()
    defp mapper(i) when rem(i, 15) == 0, do: {i, "FizzBuzz"}
    defp mapper(i) when rem(i, 5) == 0, do: {i, "Fizz"}
    defp mapper(i) when rem(i, 3) == 0, do: {i, "Buzz"}
    defp mapper(i), do: {i, "Crap"}

    #     @spec reducer(i :: non_neg_integer(), acc :: %{non_neg_integer() => binary()}) :: %{
    #         non_neg_integer() => binary()
    #       }
    # defp reducer(i, %{} = acc) when rem(i, 15) == 0, do: Map.update(acc, "FizzBuzz", 1, &(&1 + 1))
    # defp reducer(i, %{} = acc) when rem(i, 5) == 0, do: Map.update(acc, "Fizz", 1, &(&1 + 1))
    # defp reducer(i, %{} = acc) when rem(i, 3) == 0, do: Map.update(acc, "Buzz", 1, &(&1 + 1))
    # defp reducer(i, %{} = acc), do: Map.update(acc, "Crap", 1, &(&1 + 1))
  end
end
