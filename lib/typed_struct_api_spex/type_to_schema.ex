defmodule TypedStructApiSpex.TypeToSchema do
  @moduledoc false

  alias OpenApiSpex.Schema

  defmacrop only_in_test(do: block) do
    if Mix.env() == :test do
      block
    else
      :ok
    end
  end

  @spec transform(Macro.t()) :: {:ok, Schema.t()} | {:error, type_str :: String.t()}
  def transform(ast)

  #
  # `ModName.t()` cases
  #
  def transform({{:., _, [{:__aliases__, _, [mod]}, :t]}, _, []} = ast) do
    case mod do
      :String ->
        {:ok, %Schema{type: :string}}

      _ ->
        {:error, Macro.to_string(ast)}
    end
  end

  #
  # basic types except collections
  #
  def transform({:any, _, []}), do: {:ok, %Schema{}}

  def transform({:atom, _, []}), do: {:ok, %Schema{type: :string}}

  def transform({:integer, _, []}), do: {:ok, %Schema{type: :integer}}
  def transform({:neg_integer, _, []}), do: {:ok, %Schema{type: :integer, maximum: -1}}
  def transform({:non_neg_integer, _, []}), do: {:ok, %Schema{type: :integer, minimum: 0}}
  def transform({:pos_integer, _, []}), do: {:ok, %Schema{type: :integer, minimum: 1}}
  def transform({:float, _, []}), do: {:ok, %Schema{type: :number}}

  def transform({:boolean, _, []}), do: {:ok, %Schema{type: :boolean}}

  #
  # Lists
  #
  def transform({:list, _, []}), do: {:ok, list()}
  def transform({:nonempty_list, _, []}), do: {:ok, nonempty_list()}

  def transform({:list, _, [type]}) do
    case transform(type) do
      {:ok, schema} -> {:ok, list(schema)}
      error -> error
    end
  end

  def transform([{:..., _, nil}]), do: {:ok, nonempty_list()}

  def transform([type]) do
    case transform(type) do
      {:ok, schema} -> {:ok, list(schema)}
      error -> error
    end
  end

  def transform([type, {:..., _, nil}]) do
    case transform(type) do
      {:ok, schema} -> {:ok, nonempty_list(schema)}
      error -> error
    end
  end

  #
  # Maps
  #
  def transform({:map, _, []}), do: {:ok, %Schema{type: :object, additionalProperties: true}}

  def transform({:%{}, _, []}), do: {:ok, %Schema{type: :object}}

  def transform({:%{}, _, children} = ast) do
    if Keyword.keyword?(children) do
      transform_map_with_keys(children)
    else
      case children do
        [{_, value_type}] ->
          transform_map_with_pairs(value_type)

        _ ->
          {:error, Macro.to_string(ast)}
      end
    end
  end

  #
  # Literals
  #
  def transform(ast) when is_atom(ast) do
    {:ok, %Schema{type: :string, enum: [to_string(ast)]}}
  end

  def transform(ast) when is_integer(ast) do
    {:ok, %Schema{type: :integer, minimum: ast, maximum: ast}}
  end

  def transform({:.., _, [min, max]}) do
    {:ok, %Schema{type: :integer, minimum: min, maximum: max}}
  end

  #
  # Unhandled types results in error
  #
  def transform(ast) do
    only_in_test do
      # credo:disable-for-next-line
      IO.inspect(ast, label: "unhandled type AST", syntax_colors: IO.ANSI.syntax_colors())
    end

    {:error, Macro.to_string(ast)}
  end

  defp list, do: %Schema{type: :array, items: %Schema{}}
  defp list(schema), do: %Schema{type: :array, items: schema}

  defp nonempty_list, do: %Schema{type: :array, items: %Schema{}, minItems: 1}
  defp nonempty_list(schema), do: %Schema{type: :array, items: schema, minItems: 1}

  defp transform_map_with_keys(children) do
    props_or_error =
      children
      |> Enum.reduce_while(%{}, fn {key, type}, acc ->
        case transform(type) do
          {:ok, schema} -> {:cont, Map.put(acc, key, schema)}
          error -> {:halt, error}
        end
      end)

    case props_or_error do
      props when is_map(props) ->
        {:ok,
         %Schema{
           type: :object,
           required: Map.keys(props),
           properties: props
         }}

      error ->
        error
    end
  end

  defp transform_map_with_pairs(value_type) do
    case transform(value_type) do
      {:ok, value_schema} ->
        {:ok, %Schema{type: :object, additionalProperties: value_schema}}

      error ->
        error
    end
  end
end
