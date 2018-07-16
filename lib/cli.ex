defmodule CLI do
  def main(args \\ []) do
    {:ok, pid} =
      args
      |> parse_args
      |> Maestro.start_link()

    ref = Process.monitor(pid)

    receive do
      {:DOWN, ^ref, :process, _object, reason} ->
	exit(reason)
    end
  end

  def parse_args(args) do
    {opts, [], []} =
      OptionParser.parse(
	args,
	switches: [preemptible: :boolean, rho_percent: :float]
      )

    opts
  end
end
