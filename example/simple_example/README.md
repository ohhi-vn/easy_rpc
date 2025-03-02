# SimpleExample

This will use `easy_rpc` to call to `RemoteNode.Interface`.

## Guide

Need to run with `simple_example` to test.

```Elixir
mix deps.get


iex --name example@127.0.0.1 --cookie need_to_change_this -S mix

# make sure connected to remote node by cmd:
Node.list()
# return [:"remote@127.0.0.1"]

SimpleExample.Local.hello_with_name_age("Man", 40)
# return from remote: "Hello, manh! Your age is 40."
```
