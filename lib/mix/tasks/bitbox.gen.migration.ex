defmodule Mix.Tasks.Txbox.Gen.Migration do
  @shortdoc "Generates Txbox's migration"

  @moduledoc """
  Generates the required Txbox database migration.
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

      source_path = :txbox
      |> Application.app_dir()
      |> Path.join("priv/templates/migration.exs.eex")

      generated_file = source_path
      |> EEx.eval_file(module_prefix: app_module())

      target_file = Path.join(path, "#{timestamp()}_setup_txbox.exs")
      create_directory(path)
      create_file(target_file, generated_file)
    end)
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
