defmodule TypedStructApiSpex do
  @moduledoc """
  Documentation for `TypedStructApiSpex`.
  """
  use TypedStruct.Plugin

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
  def field(name, type, _opts, env) do
    schema_for_type =
      case TypeToSchema.transform(type) do
        {:ok, schema} ->
          schema

        :error ->
          "Elixir." <> module_name = env.module |> to_string()

          Logger.warn(
            "Field `#{name}` of struct `#{module_name}`: type `#{Macro.to_string(type)}` cannot be automatically transformed into OpenAPI schema. Falling back to empty schema (empty schema represents \"any\" type)"
          )

          %OpenApiSpex.Schema{}
      end

    quote do
      @typed_struct_api_spex_fields {unquote(name), unquote(Macro.escape(schema_for_type))}
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
          properties: Map.new(@typed_struct_api_spex_fields)
        }
      end
    end
  end
end
