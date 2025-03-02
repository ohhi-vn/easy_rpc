defmodule RemoteNode.Interface do
  @moduledoc """
  This is an interface for SimpleExample call in cluster.
  """

  @doc """
  Return "Hello, world!" string.
  """
  def say_hello do
    "Hello, world!"
  end

  @doc """
  Return Hello with name string.
  """
  def say_hello_to(name) do
    "Hello, #{name}!"
  end

  @doc """
  Return Hello with name and age string.
  """
  def say_hello_to_with_age(name, age) do
    "Hello, #{name}! Your age is #{age}."
  end

  @doc """
  Raise an exception.
  """
  def raise_exception do
    raise "An exception is raised."
  end
end
