defmodule Distributions do
  def constant(k) do
    fn _ -> k end
  end

  defp data_size_ppf(s) do
    1
  end

  def data_size() do
    &data_size_ppf/1
  end
end
