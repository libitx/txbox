defmodule Mix.Tasks.Txbox.Gen.Migrations do
  @shortdoc "Generates Txbox's migrations"

  @moduledoc """
  Generates the required Txbox database migrations.
  """
  use Mix.Task
  import Mix.Generator

  @doc false
  def run(args) do
    Mix.Ecto.no_umbrella!("ecto.gen.migration")

    repos = Mix.Ecto.parse_repo(args)

    Enum.each(repos, fn repo ->
      Mix.Ecto.ensure_repo(repo, args)
      path = Ecto.Migrator.migrations_path(repo)
      create_directory(path)

      :txbox
      |> Application.app_dir()
      |> Path.join("priv/templates/migrations/*.exs.eex")
      |> Path.wildcard
      |> Enum.filter(& target_nonexistent?(&1, path))
      |> Enum.each(& copy_migration(&1, path))
    end)
  end

  defp target_nonexistent?(source_path, target_path) do
    basename = source_path
    |> Path.basename(".exs.eex")
    |> String.replace(~r/^\d_/, "")

    target_path
    |> Path.join("*_#{basename}.exs")
    |> Path.wildcard
    |> Enum.empty?
  end

  defp copy_migration(source_path, target_path) do
    basename = source_path
    |> Path.basename(".exs.eex")
    |> String.replace(~r/^\d_/, "")

    target_file = Path.join(target_path, "#{timestamp()}_#{basename}.exs")
    generated_file = EEx.eval_file(source_path, module_prefix: app_module())
    create_file(target_file, generated_file)
  end

  defp app_module do
    Mix.Project.config()
    |> Keyword.fetch!(:app)
    |> to_string()
    |> Macro.camelize()
  end

  defp timestamp do
    {{y, m, d}, {hh, mm, ss}} = :calendar.universal_time()
    "#{y}#{pad(m)}#{pad(d)}#{pad(hh)}#{pad(mm)}#{pad(ss)}"
  end

  defp pad(i) when i < 10, do: <<?0, ?0 + i>>
  defp pad(i), do: to_string(i)
end
