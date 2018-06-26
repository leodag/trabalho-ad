defmodule Arrival do
  @enforce_keys [:time]
  defstruct [:time, :type, :size, :producer, :number_in_sequence, :total_sequence]
end
