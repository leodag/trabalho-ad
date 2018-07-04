defmodule Arrival do
  @enforce_keys [:time]
  defstruct [:time, :type, :size, :producer, :number_in_sequence, :total_sequence]
end

defmodule Departure do
  @enforce_keys [:time]
  defstruct [:time, :type, :size, :producer, :number_in_sequence, :total_sequence,
	     :serve_begin, :serve_end, :serve_time]
end

defmodule Packet do
  @enforce_keys [:time, :size, :type, :from]
  defstruct [:time, :size, :type, :from, :arrival_time, :serve_begin, :serve_end, :serve_time]

  def new(type, time, size) do
    %Packet{type: type,
	    time: time,
	    arrival_time: time,
            size: size,
            from: self()
    }
  end

  def delay_arrival(packet, amount) do
    packet = %Packet{packet | arrival_time: packet.arrival_time + amount}
    delay(packet, amount)
  end

  def delay(packet, amount) do
    %Packet{packet | time: packet.time + amount}
  end
end
