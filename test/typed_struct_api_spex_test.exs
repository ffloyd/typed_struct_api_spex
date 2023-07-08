defmodule TypedStructApiSpexTest do
  use ExUnit.Case
  doctest TypedStructApiSpex

  test "greets the world" do
    assert TypedStructApiSpex.hello() == :world
  end
end
