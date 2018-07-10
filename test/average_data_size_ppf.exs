defmodule AverageDataSizePpf do
  use ExUnit.Case

  test "find average of 5000 uniform values" do
    values = for _ <- 1..5000 do
      :rand.uniform()
    end

    sum = values |> Enum.reduce(fn x, y -> x + y end)

    average = sum/5000

    IO.puts "Average uniform value is #{average}"
  end

  test "find average of 5000 values in the distribution" do
    values = for _ <- 1..5000 do
      Distributions.data_size_ppf(:rand.uniform())
    end

    sum = values |> Enum.reduce(fn x, y -> x + y end)

    average = sum/5000

    IO.puts "Average value in distribution is #{average}"
  end
end
