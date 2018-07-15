defmodule AverageNumberCalcTest do
  use ExUnit.Case, async: true

  test "create a average number calculator" do
    {:ok, _} = GenServer.start_link(AverageNumberCalc, {})
  end

  setup do
    {:ok, pid} = GenServer.start_link(AverageNumberCalc, {})

    {:ok, pid: pid}
  end


  test "Initial values of time is correct", %{pid: pid} do
    assert GenServer.call(pid, :time) === 0
  end

  test "Initial values of partial_sum is correct", %{pid: pid} do
    assert GenServer.call(pid, :partial_sum) === 0
  end

  test "Adding values to the calc", %{pid: pid} do
    GenServer.cast(pid, {:value, 1, 0.1})

    assert GenServer.call(pid, :partial_sum) === 0.1
    assert GenServer.call(pid, :time) === 0.1

    GenServer.cast(pid, {:value, 2, 0.2})

    assert GenServer.call(pid, :partial_sum) === 0.30000000000000004
    assert GenServer.call(pid, :time) === 0.2
  end

  test "Getting avarega number", %{pid: pid} do
    GenServer.cast(pid, {:value, 1, 0.1})
    GenServer.cast(pid, {:value, 2, 0.3})

    assert GenServer.call(pid, :mean) === 1.6666666666666667
  end
end
