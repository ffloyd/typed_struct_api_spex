defmodule TypedStructApiSpex do
  @moduledoc """
  Documentation for `TypedStructApiSpex`.
  """
  use TypedStruct.Plugin

  alias OpenApiSpex.Schema

  alias TypedStructApiSpex.TypeToSchema

  require Logger

  @impl true
  @spec init(keyword()) :: Macro.t()
  defmacro init(_opts) do
    quote do
      @behaviour OpenApiSpex.Schema

      Module.register_attribute(__MODULE__, :typed_struct_api_spex_fields, accumulate: true)
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
            Logger.warn("""
            The following type cannot be automatically converted to OpenAPI schema:

                #{type_str}

            As a fallback field `#{field_name}` of struct `#{module_name}` will use "any" type.
            """)

            %Schema{}

          {:error, :module_without_schema, module} ->
            Logger.warn("""
            The following module has no `schema/0` implementation: #{module |> inspect()}.
            Might be you forget to add `plugin TypedStructApiSpex` or implement `OpenApiSpex.Schema` behaviour.
            As a fallback field `#{field_name}` of struct `#{module_name}` will use "any" type.
            """)

            %Schema{}

          {:error, :module_missing, module} ->
            Logger.warn("""
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
      @impl OpenApiSpex.Schema
      def schema do
        "Elixir." <> module_name = __MODULE__ |> to_string()

        %OpenApiSpex.Schema{
          title: module_name,
          type: :object,
          description: @moduledoc,
          required: @enforce_keys,
          properties: Map.new(@typed_struct_api_spex_fields)
        }
      end
    end
  end
end
