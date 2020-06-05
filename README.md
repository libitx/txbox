# Bitbox

Bitbox is an Elixir implementation of the TXT document schema for storing Bitcoin transactions in your application.

* Compatible with TXT. Has a near identical schema design and API for searching and filtering
* As Bitbox is built on Ecto, you query your own database rather than a containerized HTTP process
* Like TXT, Bitbox auto-syncs with Miner API and caches signed responses
* Unlike TXT, Bitbox provides no web UI or HTTP api, leaving that in your app's domain

## Installation

The package can be installed by adding `bitbox` to your list of dependencies in mix.exs.


```elixir
def deps do
  [
    {:bitbox, "~> 0.1"}
  ]
end
```

2. Run migrations - todo
3. Configuration - todo



