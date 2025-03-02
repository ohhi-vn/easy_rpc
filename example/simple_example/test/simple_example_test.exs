defmodule SimpleExampleTest do
  use ExUnit.Case
  doctest SimpleExample

  test "greets the world" do
    assert SimpleExample.hello() == :world
  end
end
