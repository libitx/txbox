{:ok, _pid} = Bitbox.Test.Repo.start_link()
#{:ok, _pid} = Bitbox.TxStatus.Queue.start_link()
#{:ok, _pid} = Bitbox.TxStatus.Processor.start_link()

Ecto.Adapters.SQL.Sandbox.mode(Bitbox.Test.Repo, {:shared, self()})
ExUnit.start()
