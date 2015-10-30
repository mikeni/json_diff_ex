defmodule JsonDiffEx do
  @moduledoc """
  This is the documentation of JsonDiffEx.

  There are no runtime dependencies and it should be easy
  to use.

  You can use the javascript library 
  [jsondiffpatch](https://github.com/benjamine/jsondiffpatch)
  with it since it get's it's diff format from it.

  Currently the only function is diff

  ## Example

  Simple example:

      iex> JsonDiffEx.diff %{"test" => 1}, %{"test" => 2}
      %{"test" => [1, 2]}

  Now with list:

      iex> JsonDiffEx.diff %{"test" => [1,2,3]}, %{"test" => [2,3]}
      %{"test" => %{"_0" => [1, 0, 0], "_t" => "a"}}

  Now with a map in the map:

      iex> JsonDiffEx.diff %{"test" => %{"1": 1}}, %{"test" => %{"1": 2}}
      %{"test" => %{"1": [1, 2]}}

  Now with a map in an list in the map:

      iex> JsonDiffEx.diff %{"test" => [%{"1": 1}]}, %{"test" => [%{"1": 2}]}
      %{"test" => %{"0" => %{"1": [1, 2]}, "_t" => "a"}}

  """

  defp check_shift([], _) do
    []
  end


  defp check_shift([head|tail], shift_length) do
    case head do
      {_ , [_, 0, 0]} -> [head | check_shift(tail, shift_length+1)]
      {_ , [_]} -> [head | check_shift(tail, shift_length-1)]
      {<<"_", x>>, ["", y, 3]} when (x-48)-y === shift_length ->
        check_shift(tail, shift_length)
      _ -> [head | check_shift(tail, shift_length)]
    end
  end

  defp map_find_match(_, _, []) do
    []
  end

  defp map_find_match(i, value, [head | tail]) do
    {i2, value2} = case head do
      {<<"_", x>>, [value2, 0, 0]} -> {<<x>>, value2}
      _ -> {"", ""}
    end
    case i == i2 do
      true -> if is_map(value2) do
          [{i, diff(value2, value)} | tail]
        else
          [{i, [value]}] ++ [ head | tail]
        end
      false -> [head | map_find_match(i, value, tail) ]
    end
  end

  defp check_map([]) do
    []
  end

  defp check_map([head | tail]) do
    case head do
      {i, [value]} when is_map(value) -> map_find_match(i, value, tail)
      _ -> [head | check_map(tail) ]
    end
  end

  defp make_diff_list({[nil, v], i}) do
    {"_"<>to_string(i), [v, 0, 0]}
  end

  defp make_diff_list({[i2, _], i}) do
    {"_"<>to_string(i), ["", i2, 3]}
  end

  defp make_add_list({v, i}) do
    {to_string(i), [v]}
  end

  defp do_diff(l1, l2) when is_list(l1) and is_list(l2) do
    l1_in_l2 = l1
                |> Stream.map(
                    &([Enum.find_index(l2, fn(x) -> x === &1 end), &1]))
                |> Enum.with_index
    not_in_l1 = l2
                |> Stream.with_index
                |> Enum.filter(fn({x,_}) -> not x in l1 end)
    unfiltered = Enum.map(not_in_l1, &make_add_list(&1))
    ++ Enum.filter_map(l1_in_l2, fn({[i2, _], i}) ->
      i !== i2 end, &make_diff_list(&1))
    ++ [{"_t", "a"}]
    unfiltered
    |> check_shift(0)
    |> check_map
    |> Enum.into(%{})
  end

  defp do_diff(i1, i2) when not (is_list(i1) and is_list(i2))
                    and not (is_map(i1) and is_map(i2)) do
    case i1 === i2 do
      true -> nil
      false -> [i1, i2]
    end
  end

  defp do_diff(map1, map2) when is_map(map1) and is_map(map2) do
    keys_non_uniq = Map.keys(map1) ++ Map.keys(map2)
    keys_non_uniq
    |> Stream.uniq
    |> Stream.map(fn(k) ->
      case Dict.has_key?(map1, k) do
        true ->
          case Dict.has_key?(map2, k) do
            true -> {k, do_diff(Dict.get(map1, k), Dict.get(map2, k))}
            false -> {k, [Dict.get(map1, k), 0, 0]}
          end
        false -> {k, [Dict.get(map2, k)]}
      end
    end)
    |> Stream.filter(fn({_,v}) -> v !== nil end)
    |> Enum.into(%{})
  end

  @doc """
  Diff only supports Elixir's Map format but they can contain,
  lists, other maps and anything that can be compared like strings,
  numbers and boolean.
  """
  @spec diff(map, map) :: map
  def diff(map1, map2) when is_map(map1) and is_map(map2) do
    do_diff(map1, map2)
  end
end
