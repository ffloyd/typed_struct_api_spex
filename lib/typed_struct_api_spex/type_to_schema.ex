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

  @spec transform(Macro.t(), Macro.Env.t()) ::
          {:ok, Schema.t()}
          | {:error, type_str :: String.t()}
          | {:error, :module_without_schema, module()}
          | {:error, :module_missing, module()}
  def transform(ast, env)

  #
  # `ModName.t()` cases
  #
  def transform({{:., _, [{:__aliases__, _, [_]} = mod_name_ast, :t]}, _, []}, env) do
    mod_name_ast
    |> Macro.expand(env)
    |> module_schema()
  end

  #
  # basic types except collections
  #
  def transform({:any, _, []}, _), do: {:ok, %Schema{}}

  def transform({:atom, _, []}, _), do: {:ok, %Schema{type: :string}}

  def transform({:integer, _, []}, _), do: {:ok, %Schema{type: :integer}}
  def transform({:neg_integer, _, []}, _), do: {:ok, %Schema{type: :integer, maximum: -1}}
  def transform({:non_neg_integer, _, []}, _), do: {:ok, %Schema{type: :integer, minimum: 0}}
  def transform({:pos_integer, _, []}, _), do: {:ok, %Schema{type: :integer, minimum: 1}}
  def transform({:float, _, []}, _), do: {:ok, %Schema{type: :number}}

  def transform({:boolean, _, []}, _), do: {:ok, %Schema{type: :boolean}}

  #
  # Lists
  #
  def transform({:list, _, []}, _), do: {:ok, list()}
  def transform({:nonempty_list, _, []}, _), do: {:ok, nonempty_list()}

  def transform({:list, _, [type]}, env) do
    case transform(type, env) do
      {:ok, schema} -> {:ok, list(schema)}
      error -> error
    end
  end

  def transform([{:..., _, nil}], _), do: {:ok, nonempty_list()}

  def transform([type], env) do
    case transform(type, env) do
      {:ok, schema} -> {:ok, list(schema)}
      error -> error
    end
  end

  def transform([type, {:..., _, nil}], env) do
    case transform(type, env) do
      {:ok, schema} -> {:ok, nonempty_list(schema)}
      error -> error
    end
  end

  #
  # Maps
  #
  def transform({:map, _, []}, _), do: {:ok, %Schema{type: :object, additionalProperties: true}}

  def transform({:%{}, _, []}, _), do: {:ok, %Schema{type: :object}}

  def transform({:%{}, _, children} = ast, env) do
    if Keyword.keyword?(children) do
      transform_map_with_keys(children, env)
    else
      case children do
        [{_, value_type}] ->
          transform_map_with_pairs(value_type, env)

        _ ->
          {:error, Macro.to_string(ast)}
      end
    end
  end

  #
  # Literals
  #
  def transform(ast, _) when is_atom(ast) do
    {:ok, %Schema{type: :string, enum: [to_string(ast)]}}
  end

  def transform(ast, _) when is_integer(ast) do
    {:ok, %Schema{type: :integer, minimum: ast, maximum: ast}}
  end

  def transform({:.., _, [min, max]}, _) do
    {:ok, %Schema{type: :integer, minimum: min, maximum: max}}
  end

  #
  # Enums
  #
  def transform({:|, _, _} = ast, _) do
    ast_list = flat_pipe(ast)

    if Enum.all?(ast_list, &is_atom/1) do
      list =
        ast_list
        |> Enum.map(fn
          nil -> nil
          atom -> to_string(atom)
        end)

      {:ok,
       %Schema{
         type: :string,
         enum: list
       }}
    else
      {:error, Macro.to_string(ast)}
    end
  end

  #
  # Unhandled types results in error
  #
  def transform(ast, _) do
    only_in_test do
      # credo:disable-for-next-line
      IO.inspect(ast, label: "unhandled type AST", syntax_colors: IO.ANSI.syntax_colors())
    end

    {:error, Macro.to_string(ast)}
  end

  defp module_schema(module)

  defp module_schema(String), do: {:ok, %Schema{type: :string}}

  defp module_schema(module) do
    case Code.ensure_compiled(module) do
      {:module, _} ->
        if function_exported?(module, :schema, 0) do
          {:ok, module}
        else
          {:error, :module_without_schema, module}
        end

      {:error, _} ->
        {:error, :module_missing, module}
    end
  end

  defp list, do: %Schema{type: :array, items: %Schema{}}
  defp list(schema), do: %Schema{type: :array, items: schema}

  defp nonempty_list, do: %Schema{type: :array, items: %Schema{}, minItems: 1}
  defp nonempty_list(schema), do: %Schema{type: :array, items: schema, minItems: 1}

  defp transform_map_with_keys(children, env) do
    props_or_error =
      children
      |> Enum.reduce_while(%{}, fn {key, type}, acc ->
        case transform(type, env) do
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

  defp transform_map_with_pairs(value_type, env) do
    case transform(value_type, env) do
      {:ok, value_schema} ->
        {:ok, %Schema{type: :object, additionalProperties: value_schema}}

      error ->
        error
    end
  end

  # transforms ast of code like `x | y | z` into array of asts [`x`, `y`, `z`]
  @spec flat_pipe(Macro.t()) :: [Macro.t()]
  defp flat_pipe(ast)

  defp flat_pipe({:|, _, [left, right]}) do
    flat_pipe(left) ++ flat_pipe(right)
  end

  defp flat_pipe(ast), do: [ast]
end
