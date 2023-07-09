defmodule TypedStructApiSpex.TypeToSchema do
  alias OpenApiSpex.Schema

  defmacrop only_in_test(do: block) do
    if Mix.env() == :test do
      block
    else
      :ok
    end
  end

  @spec transform(Macro.t()) :: {:ok, Schema.t()} | :error
  def transform(ast)

  # handles `ModName.t()` cases
  def transform({{:., _, [{:__aliases__, _, [mod]}, :t]}, _, []}) do
    case mod do
      :String ->
        {:ok, %Schema{type: :string}}

      _ ->
        :error
    end
  end

  def transform(ast) do
    only_in_test do
      IO.inspect(ast, label: "unhandled type", syntax_colors: IO.ANSI.syntax_colors())
    end

    :error
  end
end
