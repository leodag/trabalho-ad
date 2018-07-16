defmodule Distributions do
  def constant(k) do
    fn _ -> k end
  end

  def data_size_cdf(s) when s >= 0 and s <= 64 do
    0
  end

  def data_size_cdf(s) when s >= 0 and s < 512 do
    0.3 + 0.3 / 1436 * (s - 64)
  end

  def data_size_cdf(s) when s >= 0 and s < 1500 do
    0.4 + 0.3 / 1436 * (s - 64)
  end

  def data_size_cdf(s) when s == 1500 do
    1
  end

  def data_size_ppf(s) when s >= 0 and s < 0.3 do
    64 * 8
  end

  # valor de s calculado utilizando data_size_cdf(512) - 0.1
  def data_size_ppf(s) when s >= 0 and s < 0.39359331476323123 do
    (64 + round(1436 / 0.3 * (s - 0.3))) * 8
  end

  # valor de s calculado utilizando data_size_cdf(512)
  def data_size_ppf(s) when s >= 0 and s < 0.4935933147632312 do
    512 *8
  end

  def data_size_ppf(s) when s >= 0 and s < 0.7 do
    # valor de s calculado utilizando data_size_cdf(512)
    (512 + round(1436 / 0.3 * (s - 0.4935933147632312))) * 8
  end

  def data_size_ppf(s) when s >= 0 and s <= 1 do
    1500 * 8
  end

  def data_size() do
    &data_size_ppf/1
  end
end
