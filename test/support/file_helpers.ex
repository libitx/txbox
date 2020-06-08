defmodule Txbox.Test.FileHelpers do
  @moduledoc false

  def tmp_path do
    Path.expand("../../priv/tmp", __DIR__)
  end

  def create_dir(path) do
    run_if_abs_path(&File.mkdir_p!/1, path)
  end

  def destroy_dir(path) do
    run_if_abs_path(&File.rm_rf!/1, path)
  end

  defp run_if_abs_path(fun, path) do
    if path == Path.absname(path) do
      fun.(path)
    else
      raise "Expected an absolute path"
    end
  end

end
