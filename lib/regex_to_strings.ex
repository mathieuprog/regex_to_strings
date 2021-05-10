defmodule RegexToStrings do
  @moduledoc ~S"""
  Get the strings a regex will match.
  """

  @unsupported_metacharacters [".", "*", "+", ",}"]

  @doc ~S"""
  Get the strings a regex will match.
  """
  def regex_to_strings(regex_string) do
    maybe_regex_to_strings(regex_string, raise: false)
  end

  def regex_to_strings!(regex_string) do
    maybe_regex_to_strings(regex_string, raise: true)
  end

  defp maybe_regex_to_strings(regex_string, raise: raise?) do
    regex_string
    # filter out non-capturing group syntax
    |> String.replace("?:", "")
    |> check_unsupported_metacharacter(raise: raise?)
    |> case do
      :unsupported_regex ->
        :unsupported_regex

      regex_string ->
        values =
          regex_string
          |> String.graphemes()
          # replace ranges such as "c-f" by "cdef"
          |> fill_ranges()
          |> do_regex_to_strings([], :root, [])

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

  defp do_regex_to_strings(["|" | rest_chars], current_values, :root, result) do
    do_regex_to_strings(rest_chars, [], :root, result ++ current_values)
  end

  defp do_regex_to_strings(["?" | rest_chars], current_values, :root, result) do
    current_values = Enum.map(current_values, &String.slice(&1, 0..-2)) ++ current_values
    do_regex_to_strings(rest_chars, current_values, :root, result)
  end

  defp do_regex_to_strings([char, "{", min, ",", max, "}" | rest_chars], current_values, :root, result) do
    strings =
      String.to_integer(min)..String.to_integer(max)
      |> Enum.to_list()
      |> Enum.map(&String.duplicate(char, &1))

    current_values =
      if current_values == [], do: [""], else: current_values

    current_values =
      for i <- current_values, j <- strings, do:  i <> j

    do_regex_to_strings(rest_chars, current_values, :root, result)
  end

  defp do_regex_to_strings([char, "{", repeat, "}" | rest_chars], current_values, :root, result) do
    repeat = String.to_integer(repeat)
    string = String.duplicate(char, repeat)

    current_values = Enum.map(current_values, &(&1 <> string))

    do_regex_to_strings(rest_chars, current_values, :root, result)
  end

  defp do_regex_to_strings(["[" | _] = chars, current_values, mode, result) do
    string = Enum.join(chars)
    [char_class_string] = Regex.run(~r/^\[.+?\]\??/, string)

    string_after_char_class = String.replace(string, char_class_string, "")

    optional? = String.ends_with?(char_class_string, "?")

    char_class_chars =
      char_class_string
      |> String.trim_trailing("?")
      |> String.trim_trailing("]")
      |> String.trim_leading("[")
      |> String.graphemes()

    char_class_chars =
      if optional?, do: ["" | char_class_chars], else: char_class_chars

    current_values =
      if current_values == [], do: [""], else: current_values

    current_values =
      for i <- current_values, j <- char_class_chars, do:  i <> j

    string_after_char_class
    |> String.graphemes()
    |> do_regex_to_strings(current_values, mode, result)

  end

  defp do_regex_to_strings(["(" | _] = chars, current_values, mode, result) do
    # find the string until the corresponding closing parenthesis
    {chars_in_group, 0, :found_closing} =
      Enum.reduce_while(chars, {[], -1, :not_found_closing}, fn
        "(", {chars_in_group, parentheses_nesting, :not_found_closing} ->
          {:cont, {["(" | chars_in_group], parentheses_nesting + 1, :not_found_closing}}

        ")", {chars_in_group, 0, :not_found_closing} ->
          {:cont, {[")" | chars_in_group], 0, :found_closing}}

        ")", {chars_in_group, parentheses_nesting, :not_found_closing} ->
          {:cont, {[")" | chars_in_group], parentheses_nesting - 1, :not_found_closing}}

        char, {chars_in_group, parentheses_nesting, :not_found_closing} ->
          {:cont, {[char | chars_in_group], parentheses_nesting, :not_found_closing}}

        "?", {chars_in_group, 0, :found_closing} ->
          {:halt, {["?" | chars_in_group], 0, :found_closing}}

        _, {chars_in_group, 0, :found_closing} ->
          {:halt, {chars_in_group, 0, :found_closing}}
      end)

    group_string =
      chars_in_group
      |> Enum.reverse()
      |> Enum.join()

    string_after_group = String.replace(Enum.join(chars), group_string, "")

    optional? = String.ends_with?(group_string, "?")

    strings_found_in_group =
      group_string
      |> String.trim_trailing("?")
      |> String.trim_trailing(")")
      |> String.trim_leading("(")
      |> String.graphemes()
      |> do_regex_to_strings([], :root, [])

    strings_found_in_group =
      if optional?, do: ["" | strings_found_in_group], else: strings_found_in_group

    current_values =
      if current_values == [], do: [""], else: current_values

    current_values =
      for i <- current_values, j <- strings_found_in_group, do:  i <> j

    string_after_group
    |> String.graphemes()
    |> do_regex_to_strings(current_values, mode, result)
  end

  defp do_regex_to_strings([char | rest_chars], current_values, :root, result) do
    current_values = if current_values == [], do: [""], else: current_values
    do_regex_to_strings(rest_chars, Enum.map(current_values, &(&1 <> char)), :root, result)
  end

  defp fill_ranges(list_chars) do
    index = Enum.find_index(list_chars, &(&1 == "-"))

    if index do
      <<range_start::utf8>> = Enum.at(list_chars, index - 1)
      <<range_end::utf8>> = Enum.at(list_chars, index + 1)

      values =
        Range.new(range_start, range_end)
        |> Enum.to_list()
        |> List.to_string()
        |> String.graphemes()
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
