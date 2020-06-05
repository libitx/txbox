{:ok, _pid} = Bitbox.Test.Repo.start_link()
#{:ok, _pid} = Bitbox.TxStatus.Queue.start_link()
#{:ok, _pid} = Bitbox.TxStatus.Processor.start_link()

ExUnit.start()
