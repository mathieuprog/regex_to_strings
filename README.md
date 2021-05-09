# Regex to strings

Get the strings a regex will match.

## Examples

```elixir
import RegexToStrings

regex_to_strings("11|2[25]2") == {:ok, ["11", "222", "252"]}

regex_to_strings!("8(024|53)9") == ["80249", "8539"]

regex_to_strings!("(16|7?[56])24") == ["1624", "524", "7524", "624", "7624"]

regex_to_strings!("1[03-59]") == ["10", "13", "14", "15", "19"]

regex_to_strings("1+*2") == :unsupported_regex

regex_to_strings!("1+*2") # RuntimeError: unsupported metacharacter "."
```

## Installation

Add `regex_to_strings` for Elixir as a dependency in your `mix.exs` file:

```elixir
def deps do
  [
    {:regex_to_strings, "~> 0.3.0"}
  ]
end
```

## HexDocs

HexDocs documentation can be found at [https://hexdocs.pm/regex_to_strings](https://hexdocs.pm/regex_to_strings).
