defmodule TypedStructApiSpexTest do
  use ExUnit.Case, async: true

  alias OpenApiSpex.Schema

  describe "simple 1-level struct with one string field and moduledoc" do
    defmodule OneStringField do
      @moduledoc """
      OneStringField struct moduledoc
      """
      use TypedStruct

      typedstruct do
        plugin TypedStructApiSpex

        field :a_field, String.t()
      end
    end

    test "sets title to struct name" do
      assert %Schema{title: "TypedStructApiSpexTest.OneStringField"} = OneStringField.schema()
    end

    test "creates an object schema" do
      assert %Schema{type: :object} = OneStringField.schema()
    end

    test "sets description to moduledoc content" do
      assert %Schema{description: "OneStringField struct moduledoc\n"} = OneStringField.schema()
    end

    test "creates a property with string type" do
      assert %Schema{
               properties: %{
                 a_field: %Schema{type: :string}
               }
             } = OneStringField.schema()
    end
  end
end
