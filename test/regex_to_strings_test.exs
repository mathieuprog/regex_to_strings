defmodule RegexToStringsTest do
  use ExUnit.Case
  doctest RegexToStrings

  import RegexToStrings

  test "regex" do
    assert regex_to_strings("11") == {:ok, ["11"]}
    assert regex_to_strings!("11") == ["11"]
  end

  test "regex with or" do
    assert regex_to_strings!("11|22") == ["11", "22"]
    assert regex_to_strings!("11|22|33") == ["11", "22", "33"]
  end

  test "regex with character class" do
    assert regex_to_strings!("11|2[25]2") == ["11", "222", "252"]
    assert regex_to_strings!("1[13]|2[25]2") == ["11", "13", "222", "252"]
    assert regex_to_strings!("[13]1|2[25]2") == ["11", "31", "222", "252"]
  end

  test "regex with group" do
    assert regex_to_strings!("8(024)9") == ["80249"]
    assert regex_to_strings!("8(024|53)9") == ["80249", "8539"]
  end

  test "regex with nested group" do
    assert regex_to_strings!("8(024)9") == ["80249"]
    assert regex_to_strings!("8(024|5(1[20]|1)3)9") == ["80249", "851239", "851039", "85139"]
  end

  test "one or none" do
    assert regex_to_strings!("74?576|(16|7?[56])24") == ["7576", "74576", "1624", "524", "7524", "624", "7624"]
  end

  test "regex with range" do
    assert regex_to_strings!("1[03-79]|[2-9]") == ["10", "13", "14", "15", "16", "17", "19", "2", "3", "4", "5", "6", "7", "8", "9"]
  end

  test "raise on unsupported operations" do
    assert_raise RuntimeError, "unsupported metacharacter \".\"", fn ->
      regex_to_strings!("1.1")
    end

    assert regex_to_strings("1.+2") == :unsupported_regex
  end
end
