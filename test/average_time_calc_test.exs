defmodule AverageTimeCalcTest do
  use ExUnit.Case, async: true

  test "create a average time calculator" do
    {:ok, _} = GenServer.start_link(AverageTimeCalc, {})
  end

  setup do
    {:ok, pid} = GenServer.start_link(AverageTimeCalc, {})

    {:ok, pid: pid}
  end
    

  test "Initial values of count is correct", %{pid: pid} do
    assert GenServer.call(pid, :count) === 0
  end

  test "Initial values of partial_sum is correct", %{pid: pid} do
    assert GenServer.call(pid, :partial_sum) === 0
  end

  test "Adding values to the calc", %{pid: pid} do
    GenServer.cast(pid, {:value, 20})

    assert GenServer.call(pid, :partial_sum) === 20
    assert GenServer.call(pid, :count) === 1

    GenServer.cast(pid, {:value, 10.5})

    assert GenServer.call(pid, :partial_sum) === 30.5
    assert GenServer.call(pid, :count) === 2
  end

  test "Getting avarega time", %{pid: pid} do
    GenServer.cast(pid, {:value, 20})
    GenServer.cast(pid, {:value, 10.5})

    assert GenServer.call(pid, :mean) === 15.25
  end

  test "Getting std deviation", %{pid: pid} do
    GenServer.cast(pid, {:value, 20})
    GenServer.cast(pid, {:value, 10.5})
    GenServer.cast(pid, {:value, 10})

    assert GenServer.call(pid, :mean) === 13.5
    assert GenServer.call(pid, :std_deviation) === 5.634713834792322
  end

  test "Getting confidence interval", %{pid: pid} do
    GenServer.cast(pid, {:value, 20})
    GenServer.cast(pid, {:value, 10.5})
    GenServer.cast(pid, {:value, 10})

    assert GenServer.call(pid, :interval) === {:infinity, :infinity}
  end


end
