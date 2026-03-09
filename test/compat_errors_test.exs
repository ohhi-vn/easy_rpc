defmodule EasyRpc.CompatErrorsTest do
  use ExUnit.Case, async: true
  import ExUnit.CaptureLog

  alias EasyRpc.{Error, ConfigError, RpcError}

  ## ConfigError

  describe "ConfigError.raise_error/1" do
    test "binary message raises EasyRpc.Error with :config_error type" do
      try do
        ConfigError.raise_error("bad config")
      rescue
        e in Error -> assert e.type == :config_error
      end
    end

    test "non-binary term is inspected" do
      try do
        ConfigError.raise_error({:bad, :val})
      rescue
        e in Error -> assert e.message == "{:bad, :val}"
      end
    end
  end

  describe "ConfigError.print/1" do
    test "prints config_error struct without crash" do
      err = Error.config_error("test")
      # Redirect stdout; at minimum verify no exception raised
      assert :ok == ConfigError.print(err)
    end

    test "prints arbitrary term without crash" do
      assert :ok == ConfigError.print("unexpected")
    end
  end

  describe "ConfigError.log_error/1" do
    test "logs config error" do
      err = Error.config_error("logged")
      log = capture_log(fn -> ConfigError.log_error(err) end)
      assert log =~ "logged"
    end

    test "logs arbitrary term" do
      log = capture_log(fn -> ConfigError.log_error(:unexpected) end)
      assert log =~ "unexpected"
    end
  end

  ## RpcError

  describe "RpcError.raise_error/1" do
    test "binary message raises EasyRpc.Error with :rpc_error type" do
      try do
        RpcError.raise_error("connection refused")
      rescue
        e in Error -> assert e.type == :rpc_error
      end
    end
  end

  describe "RpcError.log_error/1" do
    test "logs rpc error" do
      err = Error.rpc_error("rpc failed")
      log = capture_log(fn -> RpcError.log_error(err) end)
      assert log =~ "rpc failed"
    end
  end
end
