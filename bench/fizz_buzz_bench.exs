defmodule FizzBuzzBench do
  use Benchfella

  bench "map :enum" do
    Flows.FizzBuzz.map(:enum, 1..500, &Flows.FizzBuzz.mapper_with_delay(&1, 10))
  end

  bench "map :stream" do
    Flows.FizzBuzz.map(:stream, 1..500, &Flows.FizzBuzz.mapper_with_delay(&1, 10))
  end

  bench "map :flow" do
    Flows.FizzBuzz.map(:flow, 1..500, &Flows.FizzBuzz.mapper_with_delay(&1, 10))
  end

  bench "reduce :enum" do
    Flows.FizzBuzz.reduce(:enum, 1..500, &Flows.FizzBuzz.mapper_with_delay(&1, 10))
  end

  bench "reduce :flow" do
    Flows.FizzBuzz.reduce(:flow, 1..500, &Flows.FizzBuzz.mapper_with_delay(&1, 10))
  end
end
