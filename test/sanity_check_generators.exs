defmodule GeneratorsSanityCheck do
  use ExUnit.Case

  test "sanity check PacketGenerator (all times are increasing)" do
    PacketGenerator.start_link([], name: PacketGen)

    # obtém os tempos dos primeiros 500 pacotes
    times = for _ <- 1..500 do
      PacketGenerator.get_packet(PacketGen).time
    end

    assert are_increasing?(times)
  end

  test "sanity check VoiceGenerator (all times are increasing)" do
    VoiceGenerator.start_link([], name: PacketGen)

    times = for _ <- 1..500 do
      PacketGenerator.get_packet(PacketGen).time
    end

    assert are_increasing?(times)
  end

  test "sanity check DataGenerator (all times are increasing)" do
    DataGenerator.start_link([], name: PacketGen)

    times = for _ <- 1..500 do
      PacketGenerator.get_packet(PacketGen).time
    end

    assert are_increasing?(times)
  end

  # Verifica se os números estão em ordem crescente
  defp are_increasing?(numbers) when is_list(numbers) do
    {status, _} =
      List.foldl(numbers, {true, 0},
	fn(next, {status, last}) ->
	  {status and last <= next, next}
	end)
    status
  end
end
