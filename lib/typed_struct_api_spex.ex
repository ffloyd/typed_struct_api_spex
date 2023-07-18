defmodule TypedStructApiSpex do
  @moduledoc """
  A plugin for `typed_struct` for generating `open_api_spex` schema from type definitions.

  ## Basic example

  iex> defmodule MyStruct do
  ...>   use TypedStruct
  ...>
  ...>   typedstruct do
  ...>     plugin TypedStructApiSpex
  ...>
  ...>     field :a_field, String.t()
  ...>   end
  ...> end
  ...>
  ...> MyStruct.schema()
  %OpenApiSpex.Schema{
    title: "MyStruct",
    type: :object,
    required: [],
    properties: %{a_field: %OpenApiSpex.Schema{type: :string}},
    "x-struct": MyStruct
  }
  """
  use TypedStruct.Plugin

  alias OpenApiSpex.Schema

  alias TypedStructApiSpex.TypeToSchema

  require Logger

  @impl true
  @spec init(keyword()) :: Macro.t()
  defmacro init(opts) do
    title = Keyword.get(opts, :title)
    derive? = Keyword.get(opts, :derive?, true)

    quote do
      Module.register_attribute(__MODULE__, :typed_struct_api_spex_fields, accumulate: true)

      @typed_struct_api_spex_title unquote(title)

      if unquote(derive?) do
        @derive Enum.filter([Poison.Encoder, Jason.Encoder], &Code.ensure_loaded?/1)
      end
    end
  end

  @impl true
  @spec field(atom(), any(), keyword(), Macro.Env.t()) :: Macro.t()
  def field(field_name, type, opts, env) do
    module_name = env.module |> inspect()

    base_schema =
      Keyword.get(opts, :schema) ||
        case TypeToSchema.transform(type, env) do
          {:ok, schema} ->
            schema

          {:error, type_str} ->
            Logger.warning("""
            The following type cannot be automatically converted to OpenAPI schema:

                #{type_str}

            As a fallback field `#{field_name}` of struct `#{module_name}` will use "any" type.
            """)

            %Schema{}

          {:error, :module_without_schema, module} ->
            Logger.warning("""
            The following module has no `schema/0` implementation: #{module |> inspect()}.
            Might be you forget to add `plugin TypedStructApiSpex` or implement `OpenApiSpex.Schema` behaviour.
            As a fallback field `#{field_name}` of struct `#{module_name}` will use "any" type.
            """)

            %Schema{}

          {:error, :module_missing, module} ->
            Logger.warning("""
            The following module is not compiled: #{module |> inspect()}.
            It can happen when module defined in the same file, but after its first usage.
            As a fallback field `#{field_name}` of struct `#{module_name}` will use "any" type.
            """)

            %Schema{}
        end

    schema =
      base_schema
      |> set_if_option_present(:description, opts)
      |> set_if_option_present(:default, opts)

    quote do
      @typed_struct_api_spex_fields {unquote(field_name), unquote(Macro.escape(schema))}
    end
  end

  defp set_if_option_present(schema, key, opts) do
    value = Keyword.get(opts, key)

    if value do
      %{schema | key => value}
    else
      schema
    end
  end

  @impl true
  @spec after_definition(opts :: keyword()) :: Macro.t()
  def after_definition(_opts) do
    quote do
      require OpenApiSpex

      OpenApiSpex.schema(
        %{
          title: @typed_struct_api_spex_title,
          type: :object,
          description: @moduledoc,
          required: @enforce_keys,
          properties: Map.new(@typed_struct_api_spex_fields),
          "x-struct": __MODULE__
        },
        struct?: false,
        derive?: false
      )
    end
  end
end
