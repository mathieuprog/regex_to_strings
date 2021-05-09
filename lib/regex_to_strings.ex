defmodule RegexToStrings do
  @moduledoc ~S"""
  Get the strings a regex will match.
  """

  @unsupported_metacharacters [".", "*", "+"]

  @doc ~S"""
  Get the strings a regex will match.
  """
  def regex_to_strings(regex_string) do
    maybe_regex_to_strings(regex_string, raise: false)
  end

  def regex_to_strings!(regex_string) do
    maybe_regex_to_strings(regex_string, raise: true)
  end

  def maybe_regex_to_strings(regex_string, raise: raise?) do
    regex_string
    |> String.replace("?:", "")
    |> check_unsupported_metacharacter(raise: raise?)
    |> case do
      :unsupported_regex ->
        :unsupported_regex

      regex_string ->
        values =
          regex_string
          |> String.graphemes()
          |> fill_ranges()
          |> do_regex_to_strings([], [:root], [])

        if raise? do
          values
        else
          {:ok, values}
        end
    end
  end

  defp do_regex_to_strings([], current_values, _, result) do
    result ++ current_values
  end

  defp do_regex_to_strings(["|" | rest_chars], current_values, [:root | _] = stack_ops, result) do
    do_regex_to_strings(rest_chars, [], stack_ops, result ++ current_values)
  end

  defp do_regex_to_strings(["?" | rest_chars], current_values, [:root | _] = stack_ops, result) do
    current_values = Enum.map(current_values, &String.slice(&1, 0..-2)) ++ current_values
    do_regex_to_strings(rest_chars, current_values, stack_ops, result)
  end

  defp do_regex_to_strings(["[" | rest_chars], current_values, stack_ops, result) do
    do_regex_to_strings(rest_chars, [], [{:character_class, current_values} | stack_ops], result)
  end

  defp do_regex_to_strings(["]" | rest_chars], current_values, [{:character_class, _}, prev_mode | rest_modes], result) do
    do_regex_to_strings(rest_chars, current_values, [prev_mode | rest_modes], result)
  end

  defp do_regex_to_strings(["(" | _] = chars, current_values, stack_ops, result) do
    string = Enum.join(chars)
    [group_string] = Regex.run(~r/^\(.+\)/, string)
    string_after_group = String.replace(string, group_string, "")

    strings_found_in_group =
      group_string
      |> String.trim("(")
      |> String.trim(")")
      |> String.graphemes()
      |> do_regex_to_strings([], [:root], [])

    current_values =
      if current_values == [], do: [""], else: current_values

    current_values =
      for i <- current_values, j <- strings_found_in_group, do:  i <> j

    string_after_group
    |> String.graphemes()
    |> do_regex_to_strings(current_values, stack_ops, result)
  end

  defp do_regex_to_strings([char | rest_chars], current_values, [:root | _] = stack_ops, result) do
    current_values = if current_values == [], do: [""], else: current_values
    do_regex_to_strings(rest_chars, Enum.map(current_values, &(&1 <> char)), stack_ops, result)
  end

  defp do_regex_to_strings([char | rest_chars], current_values, [{:character_class, chars_before_char_class} | _] = stack_ops, result) do
    chars_before_char_class = if chars_before_char_class == [], do: [""], else: chars_before_char_class
    do_regex_to_strings(rest_chars, current_values ++ Enum.map(chars_before_char_class, &(&1 <> char)), stack_ops, result)
  end

  defp fill_ranges(list_chars) do
    index = Enum.find_index(list_chars, &(&1 == "-"))

    if index do
      range_start = Enum.at(list_chars, index - 1) |> String.to_integer()
      range_end = Enum.at(list_chars, index + 1) |> String.to_integer()

      values =
        Range.new(range_start, range_end)
        |> Enum.to_list()
        |> Enum.slice(1..-2)
        |> Enum.map(&to_string(&1))

      list_chars
      |> List.replace_at(index, values)
      |> List.flatten()
      |> fill_ranges()
    else
      list_chars
    end
  end

  defp check_unsupported_metacharacter(regex_string, raise: raise?) do
    @unsupported_metacharacters
    |> Enum.any?(fn metacharacter ->
      if String.contains?(regex_string, metacharacter) do
        if raise? do
          raise "unsupported metacharacter \"#{metacharacter}\""
        end

        true
      end
    end)
    |> case do
      true ->
        :unsupported_regex

      false  ->
        regex_string
    end
  end
end
