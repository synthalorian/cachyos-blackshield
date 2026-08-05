# Elixir OTP Pitfalls — ExUnit, Dialyzer, Credo

Session-tested patterns from Reticulum Link crypto foundation work.

## ExUnit

### No `tmp_dir` fixture by default

ExUnit does NOT provide a `%{tmp_dir: dir}` fixture automatically. Use:
```elixir
test "something with temp files" do
  tmp_dir = Path.join(System.tmp_dir!(), "myapp_test_#{System.unique_integer([:positive])}")
  File.mkdir_p!(tmp_dir)
  on_exit(fn -> File.rm_rf!(tmp_dir) end)
  # ... use tmp_dir
end
```

### Named GenServer process collisions in async tests

If a GenServer uses `name: __MODULE__`, two async tests starting it will collide with `{:already_started, pid}`. Fix: accept `:name` in `start_link/1`:
```elixir
def start_link(opts \\ []) do
  name = Keyword.get(opts, :name, __MODULE__)
  GenServer.start_link(__MODULE__, opts, name: name)
end
```

Then in tests:
```elixir
{:ok, pid} = MyServer.start_link(name: :test_server_1)
```

## Dialyzer

### `with` clause type inference

Dialyzer infers that a `with` block without an `else` branch always returns the success type. If the wrapped functions can return `{:error, _}`, Dialyzer will warn that error patterns are unreachable.

Fix: add an explicit `else` branch that passes through errors:
```elixir
with {:ok, a} <- might_fail(),
     {:ok, b} <- might_also_fail(a) do
  {:ok, b}
else
  error -> error
end
```

### Pattern match coverage on private functions

When Dialyzer knows a function only returns `{:ok, _}`, matching `{:error, _}` in the caller produces `pattern_match_cov`. If the function truly cannot fail, remove the dead branch. If it can fail but Dialyzer doesn't see it, add the `else` branch to the `with` in the callee.

## Credo

### Nesting depth violation

Credo enforces max nesting depth of 2. A common violation:
```elixir
case x do
  {:ok, val} ->
    case y do
      {:ok, result} ->
        case z do          # <- depth 3, credo complains
          ...
        end
    end
end
```

Fix: extract nested cases into private functions:
```elixir
case x do
  {:ok, val} -> handle_y(val)
  error -> error
end

defp handle_y(val) do
  case y do
    {:ok, result} -> handle_z(result)
    error -> error
  end
end
```
