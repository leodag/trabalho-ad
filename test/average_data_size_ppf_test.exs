defmodule AverageDataSizePpf do
  use ExUnit.Case

  test "find average of 5000 uniform values" do
    expected_average = 0.5
    values = for _ <- 1..5000 do
      :rand.uniform()
    end

    sum = values |> Enum.reduce(fn x, y -> x + y end)

    average = sum/5000

    assert average <= expected_average + expected_average * 0.05
    assert average >= expected_average - expected_average * 0.05
  end

  test "find average of 5000 values in the distribution" do
    expected_average = 750
    values = for _ <- 1..5000 do
      Distributions.data_size_ppf(:rand.uniform())
    end

    sum = values |> Enum.reduce(fn x, y -> x + y end)

    average = sum/5000

    assert average <= expected_average + expected_average * 0.05
    assert average >= expected_average - expected_average * 0.05
  end
end
