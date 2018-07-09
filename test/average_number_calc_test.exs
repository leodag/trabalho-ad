defmodule AverageNumberCalcTest do
  use ExUnit.Case, async: true

  test "create a average number calculator" do
    {:ok, _} = GenServer.start_link(AverageNumberCalc, {})
  end

  test "Initial values of time is correct" do
    {:ok, pid} = GenServer.start_link(AverageNumberCalc, {})
    assert GenServer.call(pid, :time) === 0
  end

  test "Initial values of partial_sum is correct" do
    {:ok, pid} = GenServer.start_link(AverageNumberCalc, {})
    assert GenServer.call(pid, :partial_sum) === 0
  end

  test "Adding values to the calc" do
    {:ok, pid} = GenServer.start_link(AverageNumberCalc, {})

    GenServer.cast(pid, {:value, 1, 0.1})

    assert GenServer.call(pid, :partial_sum) === 0.1
    assert GenServer.call(pid, :time) === 0.1

    GenServer.cast(pid, {:value, 2, 0.2})

    assert GenServer.call(pid, :partial_sum) === 0.30000000000000004
    assert GenServer.call(pid, :time) === 0.2
  end

  test "Getting avarega number" do
    {:ok, pid} = GenServer.start_link(AverageNumberCalc, {})

    GenServer.cast(pid, {:value, 1, 10})
    GenServer.cast(pid, {:value, 2, 30})

    assert GenServer.call(pid, :mean) === 1.6666666666666667
  end
  #
  # test "Getting std deviation" do
  #   {:ok, pid} = GenServer.start_link(AverageNumberCalc, {})
  #
  #   GenServer.cast(pid, {:value, 20})
  #   GenServer.cast(pid, {:value, 10.5})
  #   GenServer.cast(pid, {:value, 10})
  #
  #   assert GenServer.call(pid, :mean) === 13.5
  #   assert GenServer.call(pid, :std_deviation) === 5.634713834792322
  # end
  #
  # test "Getting confidence interval" do
  #   {:ok, pid} = GenServer.start_link(AverageNumberCalc, {})
  #
  #   GenServer.cast(pid, {:value, 20})
  #   GenServer.cast(pid, {:value, 10.5})
  #   GenServer.cast(pid, {:value, 10})
  #
  #   assert GenServer.call(pid, :interval) === {8.148480161362258, 18.851519838637742}
  # end
  #
  #
end
