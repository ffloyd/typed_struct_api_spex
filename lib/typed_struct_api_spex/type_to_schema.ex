defmodule TypedStructApiSpex.TypeToSchema do
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

  # handles `ModName.t()` cases
  def transform({{:., _, [{:__aliases__, _, [mod]}, :t]}, _, []} = ast) do
    case mod do
      :String ->
        {:ok, %Schema{type: :string}}

      _ ->
        {:error, Macro.to_string(ast)}
    end
  end

  def transform({:any, _, []}), do: {:ok, %Schema{}}

  def transform({:atom, _, []}), do: {:ok, %Schema{type: :string}}

  def transform({:integer, _, []}), do: {:ok, %Schema{type: :integer}}
  def transform({:neg_integer, _, []}), do: {:ok, %Schema{type: :integer, maximum: -1}}
  def transform({:non_neg_integer, _, []}), do: {:ok, %Schema{type: :integer, minimum: 0}}
  def transform({:pos_integer, _, []}), do: {:ok, %Schema{type: :integer, minimum: 1}}
  def transform({:float, _, []}), do: {:ok, %Schema{type: :number}}

  def transform({:boolean, _, []}), do: {:ok, %Schema{type: :boolean}}

  def transform({:map, _, []}), do: {:ok, %Schema{type: :object, additionalProperties: true}}

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

  def transform(ast) do
    only_in_test do
      IO.inspect(ast, label: "unhandled type AST", syntax_colors: IO.ANSI.syntax_colors())
    end

    {:error, Macro.to_string(ast)}
  end

  defp list, do: %Schema{type: :array, items: %Schema{}}
  defp list(schema), do: %Schema{type: :array, items: schema}

  defp nonempty_list, do: %Schema{type: :array, items: %Schema{}, minItems: 1}
  defp nonempty_list(schema), do: %Schema{type: :array, items: schema, minItems: 1}
end
