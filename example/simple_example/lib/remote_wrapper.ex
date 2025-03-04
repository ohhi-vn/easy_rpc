defmodule SimpleExample.Local do
  @moduledoc """
  Documentation for `SimpleExample`.
  """

  use EasyRpc.RpcWrapper,
    otp_app: :simple_example,
    config_name: :remote_wrapper

  # in other module you can call remote function like:
  # SimpleExample.Local.say_hello()

  def hello() do
    # call remote function
    private_hello()
  end
end
