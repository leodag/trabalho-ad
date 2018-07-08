defmodule Arrival do
  @enforce_keys [:time]
  defstruct [:time, :Packet]
end

defmodule Departure do
  @enforce_keys [:time]
  defstruct [:time, :Packet]
end

defmodule Packet do
  @enforce_keys [:time, :size, :from]
  defstruct [:time, :size, :from, :type, :producer, :number_in_sequence, :total_sequence, :time_on_server, :time_on_queue]
end
