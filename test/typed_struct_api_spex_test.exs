defmodule TypedStructApiSpexTest do
  use ExUnit.Case, async: true

  alias OpenApiSpex.Schema

  describe "struct with one string field and moduledoc" do
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

  describe "struct with fields that have all supported basic types, some of them required" do
    defmodule BasicTypes do
      use TypedStruct

      typedstruct do
        plugin TypedStructApiSpex

        field :an_any, any()
        field :an_atom, atom(), enforce: true
        field :an_integer, integer(), enforce: true
        field :a_negative_integer, neg_integer()
        field :a_non_negative_integer, non_neg_integer()
        field :a_positive_integer, pos_integer()
        field :a_float, float()
        field :a_map, map()
        field :a_boolean, boolean()
        field :any_list, list()
        field :a_non_empty_list, nonempty_list()
      end
    end

    test "sets required fields" do
      assert [:an_atom, :an_integer] == BasicTypes.schema().required |> Enum.sort()
    end

    test "transaltes types correctly" do
      assert BasicTypes.schema().properties ==
               %{
                 an_any: %Schema{},
                 an_atom: %Schema{
                   type: :string
                 },
                 an_integer: %Schema{
                   type: :integer
                 },
                 a_negative_integer: %Schema{
                   type: :integer,
                   maximum: -1
                 },
                 a_non_negative_integer: %Schema{
                   type: :integer,
                   minimum: 0
                 },
                 a_positive_integer: %Schema{
                   type: :integer,
                   minimum: 1
                 },
                 a_float: %Schema{
                   type: :number
                 },
                 a_map: %Schema{
                   type: :object,
                   additionalProperties: true
                 },
                 a_boolean: %Schema{
                   type: :boolean
                 },
                 any_list: %Schema{
                   type: :array,
                   items: %Schema{}
                 },
                 a_non_empty_list: %Schema{
                   type: :array,
                   items: %Schema{},
                   minItems: 1
                 }
               }
    end
  end

  describe "struct with list types, all fields are required" do
    defmodule ListTypes do
      use TypedStruct

      typedstruct enforce: true do
        plugin TypedStructApiSpex

        field :a_list_of_integers, list(integer())
        field :another_list_of_integers, [integer()]
        field :a_non_empty_list, [...]
        field :a_non_empty_list_of_strings, [String.t(), ...]
      end
    end

    test "sets required fields" do
      assert [
               :a_list_of_integers,
               :a_non_empty_list,
               :a_non_empty_list_of_strings,
               :another_list_of_integers
             ] == ListTypes.schema().required |> Enum.sort()
    end

    test "transaltes types correctly" do
      assert ListTypes.schema().properties ==
               %{
                 a_list_of_integers: %Schema{
                   type: :array,
                   items: %Schema{type: :integer}
                 },
                 another_list_of_integers: %Schema{
                   type: :array,
                   items: %Schema{type: :integer}
                 },
                 a_non_empty_list: %Schema{
                   type: :array,
                   items: %Schema{},
                   minItems: 1
                 },
                 a_non_empty_list_of_strings: %Schema{
                   type: :array,
                   items: %Schema{type: :string},
                   minItems: 1
                 }
               }
    end
  end

  describe "struct with 1-level map types" do
    defmodule SimpleMaps do
      use TypedStruct

      typedstruct do
        plugin TypedStructApiSpex

        field :an_empty_map, %{}
        field :a_map_with_atom_keys, %{key_a: integer(), key_b: String.t()}
        field :a_map_with_required_pairs, %{String.t() => float()}
        field :another_map_with_required_pairs, %{required(String.t()) => float()}
        field :a_map_with_optional_pairs, %{optional(String.t()) => float()}
      end
    end

    test "translates types correctly" do
      assert SimpleMaps.schema().properties == %{
               an_empty_map: %Schema{
                 type: :object
               },
               a_map_with_atom_keys: %Schema{
                 type: :object,
                 required: [:key_a, :key_b],
                 properties: %{
                   key_a: %Schema{type: :integer},
                   key_b: %Schema{type: :string}
                 }
               },
               a_map_with_required_pairs: %Schema{
                 type: :object,
                 additionalProperties: %Schema{type: :number}
               },
               another_map_with_required_pairs: %Schema{
                 type: :object,
                 additionalProperties: %Schema{type: :number}
               },
               a_map_with_optional_pairs: %Schema{
                 type: :object,
                 additionalProperties: %Schema{type: :number}
               }
             }
    end
  end

  describe "struct with simple literal types" do
    defmodule Literals do
      use TypedStruct

      typedstruct do
        plugin TypedStructApiSpex

        field :a_single_atom, :some_atom
        field :a_single_integer, 10
        field :a_range, 10..20
      end
    end

    test "translates types correctly" do
      assert Literals.schema().properties == %{
               a_single_atom: %Schema{
                 type: :string,
                 enum: ["some_atom"]
               },
               a_single_integer: %Schema{
                 type: :integer,
                 minimum: 10,
                 maximum: 10
               },
               a_range: %Schema{
                 type: :integer,
                 minimum: 10,
                 maximum: 20
               }
             }
    end
  end

  describe "struct with an atom enums" do
    defmodule AtomEnum do
      use TypedStruct

      typedstruct do
        plugin TypedStructApiSpex

        field :an_atom_enum, :enabled | :disabled
        field :a_long_atom_enum, :red | :green | :blue | :alpha
        field :an_enum_with_nil, :a | :b | nil
      end
    end

    test "translates types correctly" do
      assert AtomEnum.schema().properties == %{
               an_atom_enum: %Schema{
                 type: :string,
                 enum: ["enabled", "disabled"]
               },
               a_long_atom_enum: %Schema{
                 type: :string,
                 enum: ["red", "green", "blue", "alpha"]
               },
               an_enum_with_nil: %Schema{
                 type: :string,
                 enum: ["a", "b", nil]
               }
             }
    end
  end

  describe "struct with schema overrides" do
    defmodule WithOverride do
      use TypedStruct

      typedstruct do
        plugin TypedStructApiSpex

        field :with_override, String.t(), schema: %Schema{type: :string, format: :date}
      end
    end

    test "uses provided schema" do
      assert WithOverride.schema().properties == %{
               with_override: %Schema{type: :string, format: :date}
             }
    end
  end

  describe "struct with another struct as a field" do
    defmodule NestedOne do
      use TypedStruct

      typedstruct do
        plugin TypedStructApiSpex

        field :a_string, String.t()
      end
    end

    defmodule WithoutPlugin do
      use TypedStruct

      typedstruct do
        field :a_string, String.t()
      end
    end

    defmodule WithNested do
      use TypedStruct

      typedstruct do
        plugin TypedStructApiSpex

        field :a_struct, NestedOne.t()
        field :a_struct_without_schema, WithoutPlugin.t()
        field :a_missing_module, IAmMissing.t()
      end
    end

    test "translates types correctly" do
      assert WithNested.schema().properties == %{
               a_struct: NestedOne,
               a_struct_without_schema: %Schema{},
               a_missing_module: %Schema{}
             }
    end
  end

  describe "struct with another struct as a component of list" do
    defmodule Simple do
      use TypedStruct

      typedstruct do
        plugin TypedStructApiSpex

        field :a_string, String.t()
      end
    end

    defmodule WithList do
      use TypedStruct

      typedstruct do
        plugin TypedStructApiSpex

        field :a_list_of_structs, [Simple.t()]
      end
    end

    test "translates types correctly" do
      assert WithList.schema().properties == %{
               a_list_of_structs: %Schema{
                 type: :array,
                 items: Simple
               }
             }
    end
  end

  describe "struct with another struct as a component of nested map" do
    defmodule Simple do
      use TypedStruct

      typedstruct do
        plugin TypedStructApiSpex

        field :a_string, String.t()
      end
    end

    defmodule ComplexOne do
      use TypedStruct

      typedstruct do
        plugin TypedStructApiSpex

        field :a_complex_field, %{a: String.t(), b: %{x: integer(), y: Simple.t()}}
      end
    end

    test "translates types correctly" do
      assert ComplexOne.schema().properties == %{
               a_complex_field: %Schema{
                 type: :object,
                 required: [:a, :b],
                 properties: %{
                   a: %Schema{type: :string},
                   b: %Schema{
                     type: :object,
                     required: [:x, :y],
                     properties: %{
                       x: %Schema{type: :integer},
                       y: Simple
                     }
                   }
                 }
               }
             }
    end
  end
end
