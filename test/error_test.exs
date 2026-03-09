defmodule EasyRpc.ErrorTest do
  use ExUnit.Case, async: true
  import ExUnit.CaptureLog

  alias EasyRpc.Error

  # Sub-modules whose names are recognised by classify_exception/1
  defmodule FakeTimeoutError, do: defexception([:message])
  defmodule FakeNodeDownError, do: defexception([:message])
  defmodule FakeNoConnectionError, do: defexception([:message])

  ## ---- Constructors ----

  describe "config_error/1,2" do
    test "binary message stores it directly" do
      err = Error.config_error("bad timeout")
      assert %Error{type: :config_error, message: "bad timeout"} = err
    end

    test "non-binary term is inspected into message" do
      err = Error.config_error({:bad, :value})
      assert err.message == "{:bad, :value}"
    end

    test "details default to []" do
      assert Error.config_error("msg").details == []
    end

    test "details keyword list is stored" do
      err = Error.config_error("msg", key: :timeout, got: -1)
      assert err.details == [key: :timeout, got: -1]
    end
  end

  describe "rpc_error/1,2" do
    test "creates :rpc_error type" do
      assert Error.rpc_error("refused").type == :rpc_error
    end

    test "stores node in details" do
      err = Error.rpc_error("failed", node: :n1@host)
      assert err.details[:node] == :n1@host
    end
  end

  describe "node_error/1,2" do
    test "creates :node_error type" do
      assert Error.node_error("gone").type == :node_error
    end
  end

  describe "timeout_error/1,2" do
    test "creates :timeout_error type" do
      assert Error.timeout_error("5000ms").type == :timeout_error
    end
  end

  describe "validation_error/1,2" do
    test "creates :validation_error type" do
      assert Error.validation_error("bad input").type == :validation_error
    end
  end

  ## ---- format/1 ----

  describe "format/1" do
    test "omits details section when nil" do
      err = %Error{type: :rpc_error, message: "oops", details: nil}
      assert Error.format(err) == "[rpc_error] oops"
    end

    test "omits details section when empty list" do
      err = Error.rpc_error("oops")
      assert Error.format(err) == "[rpc_error] oops"
    end

    test "includes details section when populated" do
      err = Error.rpc_error("oops", node: :n1@h, attempt: 2)
      formatted = Error.format(err)
      assert formatted =~ "[rpc_error] oops"
      assert formatted =~ "details:"
      assert formatted =~ ":n1@h"
    end
  end

  ## ---- raise! ----

  describe "raise!/2,3 — from type + message" do
    test "raises EasyRpc.Error" do
      assert_raise Error, fn -> Error.raise!(:rpc_error, "boom") end
    end

    test "sets type and message correctly" do
      try do
        Error.raise!(:timeout_error, "timed out", attempt: 3)
      rescue
        e in Error ->
          assert e.type == :timeout_error
          assert e.message == "timed out"
          assert e.details == [attempt: 3]
      end
    end
  end

  describe "raise!/1 — from struct" do
    test "re-raises the given Error struct unchanged" do
      original = Error.node_error("gone", node: :n1)

      try do
        Error.raise!(original)
      rescue
        e in Error ->
          assert e.type == :node_error
          assert e.message == "gone"
          assert e.details[:node] == :n1
      end
    end
  end

  ## ---- wrap_exception/2 ----

  describe "wrap_exception/2" do
    test "captures exception message" do
      err = Error.wrap_exception(%RuntimeError{message: "boom"})
      assert err.message == "boom"
    end

    test "stores original exception module in details" do
      err = Error.wrap_exception(%RuntimeError{message: "boom"}, node: :n1)
      assert err.details[:exception] == RuntimeError
      assert err.details[:node] == :n1
    end

    test "defaults to :rpc_error for unknown exceptions" do
      err = Error.wrap_exception(%RuntimeError{message: "x"})
      assert err.type == :rpc_error
    end

    test "classifies timeout by exception module name" do
      err = Error.wrap_exception(%EasyRpc.ErrorTest.FakeTimeoutError{message: "t/o"})
      assert err.type == :timeout_error
    end

    test "classifies nodedown by exception module name" do
      err = Error.wrap_exception(%EasyRpc.ErrorTest.FakeNodeDownError{message: "down"})
      assert err.type == :node_error
    end

    test "classifies noconnection by exception module name" do
      err = Error.wrap_exception(%EasyRpc.ErrorTest.FakeNoConnectionError{message: "no conn"})
      assert err.type == :node_error
    end
  end

  ## ---- Exception.message/1 callback ----

  describe "message/1 (Exception callback)" do
    test "returns the same string as format/1" do
      err = Error.rpc_error("failed", node: :n1)
      assert Exception.message(err) == Error.format(err)
    end
  end

  ## ---- log/2 ----

  describe "log/2" do
    test "defaults to :error level and includes formatted message" do
      err = Error.config_error("bad config")
      log = capture_log(fn -> Error.log(err) end)
      assert log =~ "[config_error] bad config"
    end

    test ":warning level is captured" do
      err = Error.node_error("unreachable")
      log = capture_log(fn -> Error.log(err, :warning) end)
      assert log =~ "[node_error] unreachable"
    end

    test ":info level is captured" do
      err = Error.rpc_error("info msg")
      log = capture_log([level: :info], fn -> Error.log(err, :info) end)
      assert log =~ "[rpc_error] info msg"
    end
  end
end
