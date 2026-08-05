---
name: elixir-otp-network-protocols
description: >
  Build network protocol implementations in Elixir/OTP: GenServer state machines,
  ETS-backed routing tables, DynamicSupervisor child management, PubSub decoupling,
  and transport layer patterns. Covers the full stack from packet parsing to
  link management to transport forwarding.
  Triggers: elixir network protocol, genserver state machine, ets routing table,
  dynamic supervisor, pubsub transport, link manager, packet handler, mesh network,
  reticulum, protocol implementation, otp networking.
version: 1.0.0
tags: [elixir, otp, network, protocol, genserver, ets, supervisor, pubsub, transport]
related_skills: [elixir-crypto-debugging]
---

## Elixir/OTP Network Protocol Implementation

Build network protocol stacks in Elixir/OTP — from packet parsing through link management to transport forwarding. This skill covers the architectural patterns, not specific wire formats.

## Triggers
- Implementing a network protocol in Elixir (mesh, p2p, overlay, etc.)
- Building link/connection state machines
- Managing per-peer processes with supervisors
- Routing table implementations
- Transport layer packet forwarding
- PubSub-based decoupled architectures
- Phoenix REST API + WebSocket for protocol management
- Token-based API authentication for protocol nodes

## Architecture Overview

```
Transport Layer (coordinator)
    ├── LinkManager (DynamicSupervisor)
    │       └── Link (GenServer per connection)
    ├── PathManager (GenServer + ETS)
    ├── AnnounceHandler (GenServer + ETS)
    └── Interface Layer (PubSub subscribers)
```

## 1. GenServer State Machines for Protocol Links

Use explicit atom states with guarded transitions:

```elixir
defmodule MyProtocol.Link do
  use GenServer
  require Logger

  @states [:pending, :handshake, :active, :stale, :closed]

  defstruct [
    :id, :state, :peer_pubkey, :shared_secret,
    :tx_key, :rx_key, :tx_seq, :rx_seq,
    :created_at, :last_activity, :watchdog_ref
  ]

  # --- Client API ---

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  def send_data(pid, data) do
    GenServer.call(pid, {:send, data})
  end

  def close(pid) do
    GenServer.cast(pid, :close)
  end

  # --- Server ---

  @impl true
  def init(opts) do
    state = %__MODULE__{
      id: Keyword.fetch!(opts, :id),
      state: :pending,
      peer_pubkey: Keyword.fetch!(opts, :peer_pubkey),
      created_at: System.monotonic_time(:second),
      last_activity: System.monotonic_time(:second),
      tx_seq: 0,
      rx_seq: 0
    }

    # Schedule watchdog
    ref = Process.send_after(self(), :watchdog, 30_000)
    {:ok, %{state | watchdog_ref: ref}}
  end

  @impl true
  def handle_call({:send, data}, _from, %{state: :active} = state) do
    # Encrypt, increment seq, send
    new_state = %{state | tx_seq: state.tx_seq + 1, last_activity: System.monotonic_time(:second)}
    {:reply, :ok, new_state}
  end

  def handle_call({:send, _}, _from, state) do
    {:reply, {:error, :link_not_active}, state}
  end

  @impl true
  def handle_cast(:close, state) do
    {:stop, :normal, %{state | state: :closed}}
  end

  @impl true
  def handle_info(:watchdog, state) do
    now = System.monotonic_time(:second)
    stale_after = 720

    cond do
      state.state == :closed ->
        {:stop, :normal, state}

      now - state.last_activity > stale_after ->
        Logger.warning("Link #{state.id} stale, closing")
        {:stop, :normal, %{state | state: :stale}}

      true ->
        ref = Process.send_after(self(), :watchdog, 30_000)
        {:noreply, %{state | watchdog_ref: ref}}
    end
  end

  def handle_info(:keepalive, %{state: :active} = state) do
    # Send keepalive packet
    ref = Process.send_after(self(), :keepalive, 360_000)
    {:noreply, %{state | last_activity: System.monotonic_time(:second), watchdog_ref: ref}}
  end
end
```

**Key patterns:**
- Store timer refs and cancel on state change
- Use `System.monotonic_time(:second)` for all timeouts (immune to clock changes)
- Return `{:stop, :normal, state}` from `handle_info` for graceful shutdown
- Reject operations in wrong states with explicit error atoms

## 2. DynamicSupervisor for Per-Link Processes

```elixir
defmodule MyProtocol.LinkManager do
  use DynamicSupervisor

  def start_link(opts \\ []) do
    DynamicSupervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    # :temporary — crashed links stay dead; caller decides retry
    DynamicSupervisor.init(strategy: :one_for_one, max_restarts: 100)
  end

  def start_link_initiator(peer_id, peer_pubkey, opts \\ []) do
    spec = %{
      id: {MyProtocol.Link, peer_id},
      start: {MyProtocol.Link, :start_link, [[
        id: peer_id,
        peer_pubkey: peer_pubkey,
        role: :initiator
      ] ++ opts]},
      restart: :temporary,
      shutdown: 5_000
    }
    DynamicSupervisor.start_child(__MODULE__, spec)
  end

  def start_link_responder(peer_id, peer_pubkey, ephemeral_key, opts \\ []) do
    spec = %{
      id: {MyProtocol.Link, peer_id},
      start: {MyProtocol.Link, :start_link, [[
        id: peer_id,
        peer_pubkey: peer_pubkey,
        ephemeral_key: ephemeral_key,
        role: :responder
      ] ++ opts]},
      restart: :temporary,
      shutdown: 5_000
    }
    DynamicSupervisor.start_child(__MODULE__, spec)
  end

  def terminate_link(pid) do
    DynamicSupervisor.terminate_child(__MODULE__, pid)
  end

  def link_count do
    DynamicSupervisor.count_children(__MODULE__)
    |> Map.get(:active)
  end
end
```

**Why `:temporary` restart?** Crashed links should not auto-restart. The transport layer decides whether to retry based on path availability and retry policy. Prevents restart loops on persistent failures.

## 3. ETS Routing Tables (Unnamed Pattern)

Named ETS tables collide in async tests. Use unnamed tables stored in GenServer state:

**Critical:** Every GenServer that owns an ETS table must also accept a `:name` option so tests can start isolated instances:

```elixir
defmodule MyProtocol.PathManager do
  use GenServer

  defstruct [:table, :pubsub]

  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @impl true
  def init(opts) do
    table = :ets.new(:path_table, [:set, :protected])
    pubsub = Keyword.get(opts, :pubsub, MyProtocol.PubSub)
    {:ok, %__MODULE__{table: table, pubsub: pubsub}}
  end

  # Client API — all go through GenServer calls (NOT direct :ets.lookup)
  # This is required when table is unnamed (no :named_table)
  def register_path(server \\ __MODULE__, destination_hash, next_hop, hops, expires_at) do
    GenServer.call(server, {:register, destination_hash, next_hop, hops, expires_at})
  end

  def lookup_path(server \\ __MODULE__, destination_hash) do
    GenServer.call(server, {:lookup, destination_hash})
  end

  def all_paths(server \\ __MODULE__) do
    GenServer.call(server, :all_paths)
  end

  def delete_path(server \\ __MODULE__, destination_hash) do
    GenServer.call(server, {:delete, destination_hash})
  end

  # Server handlers
  @impl true
  def handle_call({:register, hash, hop, hops, expires}, _from, state) do
    :ets.insert(state.table, {hash, %{next_hop: hop, hops: hops, expires_at: expires}})
    {:reply, :ok, state}
  end

  def handle_call({:lookup, hash}, _from, state) do
    result = case :ets.lookup(state.table, hash) do
      [{_, path}] -> {:ok, path}
      [] -> :error
    end
    {:reply, result, state}
  end

  def handle_call(:all_paths, _from, state) do
    paths = :ets.tab2list(state.table)
    {:reply, paths, state}
  end

  def handle_call({:delete, hash}, _from, state) do
    :ets.delete(state.table, hash)
    {:reply, :ok, state}
  end
end
```

**Test isolation pattern:**

```elixir
describe "PathManager" do
  setup do
    name = String.to_atom("test_path_mgr_#{:erlang.unique_integer([:positive])}")
    {:ok, mgr} = PathManager.start_link(name: name)
    %{mgr: mgr}
  end

  test "registers and looks up paths", %{mgr: mgr} do
    :ok = PathManager.register_path(mgr, <<0::128>>, "hop1", 1, 9999999999)
    assert {:ok, _} = PathManager.lookup_path(mgr, <<0::128>>)
  end
end
```

## ETS Match Spec Pitfalls

### Quoted vs Unquoted Wildcards
In Elixir match specs, use `:_` (unquoted) not `:"_"` (quoted):

```elixir
# WRONG — quoted atom triggers compiler warning
:ets.select(state.table, [
  {{:"$1", :"_", :"$2", :"_"}, [{:<, :"$2", now}], [:"$1"]}
])

# CORRECT — unquoted wildcard
:ets.select(state.table, [
  {{:"$1", :_, :"$2", :_}, [{:<, :"$2", now}], [:"$1"]}
])
```

### Map Match Spec Syntax

```elixir
# WRONG — :_ => :_ is invalid in match spec
:ets.select(state.table, [
  {{:_, %{expires_at: :"$1", :_ => :_}}, [], [:"$1"]}
])

# CORRECT — match only needed fields
:ets.select(state.table, [
  {{:_, %{expires_at: :"$1"}}, [], [:"$1"]}
])
```

### Boolean Operators in Match Specs
Use `:orelse` / `:andalso`, not `:or` / `:and`:

```elixir
# WRONG — :or is not a valid match spec operator
:ets.select(state.table, [
  {{:"$1", :"$2", :_, :_, :_, :_}, [{:or, {:==, :"$2", :pending}, {:==, :"$2", :propagated}}], [:"$1"]}
])

# CORRECT — use :orelse
:ets.select(state.table, [
  {{:"$1", :"$2", :_, :_, :_, :_},
   [{:orelse, {:==, :"$2", :pending}, {:==, :"$2", :propagated}}], [:"$1"]}
])
```

### ETS Match Spec Quoted-Atom Pitfall

In Elixir match specs, use `:_` (unquoted) not `:"_"` (quoted):

```elixir
# WRONG — quoted atom triggers compiler warning "found quoted atom '_' but quotes are not required"
:ets.select(state.table, [
  {{:"$1", :"_", :"$2", :"_"}, [{:<, :"$2", now}], [:"$1"]}
])

# CORRECT — unquoted wildcard
:ets.select(state.table, [
  {{:"$1", :_, :"$2", :_}, [{:<, :"$2", now}], [:"$1"]}
])
```
```

### ETS Match Spec Quoted-Atom Pitfall

In Elixir match specs, use `:_` (unquoted) not `:"_"` (quoted):

```elixir
# WRONG — quoted atom triggers compiler warning "found quoted atom '_' but quotes are not required"
:ets.select(state.table, [
  {{:"$1", :"_", :"$2", :"_"}, [{:<, :"$2", now}], [:"$1"]}
])

# CORRECT — unquoted wildcard
:ets.select(state.table, [
  {{:"$1", :_, :"$2", :_}, [{:<, :"$2", now}], [:"$1"]}
])
```

**Periodic cleanup:** Use `Process.send_after/3` to schedule TTL expiration:

```elixir
defp schedule_cleanup(interval \\ 60_000) do
  Process.send_after(self(), :cleanup, interval)
end

@impl true
def handle_info(:cleanup, state) do
  now = System.monotonic_time(:second)
  # Select expired entries
  expired = :ets.select(state.table, [
    {{:_, %{expires_at: :"$1"}}, [{:<, :"$1", now}], [true]}
  ])
  # Delete them
  for {hash, _} <- expired, do: :ets.delete(state.table, hash)
  schedule_cleanup()
  {:noreply, state}
end
```

## 4. PubSub Decoupling

Decouple interface layer from transport layer via PubSub topics:

```elixir
defmodule MyProtocol.Interface do
  def init(opts) do
    pubsub = Keyword.fetch!(opts, :pubsub)
    Phoenix.PubSub.subscribe(pubsub, "myproto:packets")
    {:ok, %{pubsub: pubsub}}
  end

  def handle_info({:packet, raw_packet, meta}, state) do
    # Parse packet, dispatch to appropriate handler
    case parse_packet(raw_packet) do
      {:announce, announce} ->
        Phoenix.PubSub.broadcast(state.pubsub, "myproto:announces", {:announce, announce, meta})
      {:path_request, req} ->
        Phoenix.PubSub.broadcast(state.pubsub, "myproto:path_requests", {:path_request, req, meta})
      {:link_data, data} ->
        # Route to specific link process
        send_link(data.link_id, {:data, data.payload})
    end
    {:noreply, state}
  end
end
```

**Topic conventions:**
- `"myproto:packets"` — raw incoming packets from all interfaces
- `"myproto:announces"` — parsed announce packets
- `"myproto:path_requests"` — path discovery broadcasts
- `"myproto:forward"` — packets to be forwarded to next hop

## 5. Supervisor Wiring

```elixir
defmodule MyProtocol.Transport.Supervisor do
  use Supervisor

  def start_link(opts \\ []) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(opts) do
    pubsub = Keyword.get(opts, :pubsub, MyProtocol.PubSub)

    children = [
      {MyProtocol.PathManager, [pubsub: pubsub]},
      {MyProtocol.AnnounceHandler, [pubsub: pubsub]},
      {MyProtocol.LinkManager, []},
      {MyProtocol.Transport, [pubsub: pubsub, enabled: false]}
    ]

    Supervisor.init(children, strategy: :one_for_all)
  end
end
```

**Why `:one_for_all`?** If the PubSub crashes, all transport components need restart. If LinkManager crashes, PathManager and AnnounceHandler should restart to clear stale state.

## 6. Transport Mode Coordinator

```elixir
defmodule MyProtocol.Transport do
  use GenServer

  defstruct [:enabled, :max_hops, :pubsub, :dropped, :transit]

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(opts) do
    pubsub = Keyword.get(opts, :pubsub, MyProtocol.PubSub)
    Phoenix.PubSub.subscribe(pubsub, "myproto:forward")

    {:ok, %__MODULE__{
      enabled: Keyword.get(opts, :enabled, false),
      max_hops: Keyword.get(opts, :max_hops, 128),
      pubsub: pubsub,
      dropped: 0,
      transit: 0
    }}
  end

  def enable, do: GenServer.call(__MODULE__, :enable)
  def disable, do: GenServer.call(__MODULE__, :disable)

  @impl true
  def handle_call(:enable, _from, state), do: {:reply, :ok, %{state | enabled: true}}
  def handle_call(:disable, _from, state), do: {:reply, :ok, %{state | enabled: false}}

  @impl true
  def handle_info({:forward, packet, next_hop}, %{enabled: true} = state) do
    if packet.hops < state.max_hops and not local_destination?(packet.destination) do
      # Forward to next_hop interface
      Phoenix.PubSub.broadcast(state.pubsub, "myproto:packets", {:send, packet, next_hop})
      {:noreply, %{state | transit: state.transit + 1}}
    else
      {:noreply, %{state | dropped: state.dropped + 1}}
    end
  end

  def handle_info({:forward, _packet, _next_hop}, state) do
    {:noreply, %{state | dropped: state.dropped + 1}}
  end

  defp local_destination?(hash) do
    # Check against local identity
    MyProtocol.Identity.local_hash() == hash
  end
end
```

## Researching Python Reference Implementations

When interoperating with a Python protocol (e.g., Reticulum), create a project-local venv to inspect constants and source:

```bash
cd /path/to/project
python3 -m venv .venv
.venv/bin/pip install <package-name>

# Extract constants
.venv/bin/python3 -c "
import RNS
for name in dir(RNS):
    val = getattr(RNS, name)
    if not name.startswith('_'):
        print(f'{name} = {val}')
"

# Inspect source for specific functions
.venv/bin/python3 -c "
import RNS, inspect
print(inspect.getsource(RNS.Link))
"
```

**Why venv instead of system packages:**
- Avoids `--break-system-packages` (PEP 668 blocked on Arch)
- Keeps research dependencies out of system Python
- `.venv/` is already in most `.gitignore` templates
- Can be deleted after research: `rm -rf .venv`

**Pitfall:** `pip install` without venv on Arch fails with PEP 668. Always use `python3 -m venv` first.

**LXMF research:** For LXMF (Reticulum messaging layer), install both `rns` and `lxmf`:

```bash
.venv/bin/pip install rns lxmf
.venv/bin/python3 -c "
import LXMF
import inspect
print(inspect.getsource(LXMF.LXMessage))
"
```

Key LXMF constants to extract:
- `LXMF.LXMessage.DESTINATION_LENGTH` = 16
- `LXMF.LXMessage.SIGNATURE_LENGTH` = 64
- `LXMF.LXMessage.TIMESTAMP_SIZE` = 8
- `LXMF.LXMessage.DIRECT` = 2, `OPPORTUNISTIC` = 1, `PROPAGATED` = 3
- `LXMF.LXMessage.PACKET` = 1, `RESOURCE` = 2
- `LXMF.LXMessage.GENERATING` = 0, `OUTBOUND` = 1, `SENDING` = 2, `SENT` = 4, `DELIVERED` = 8, `FAILED` = 255

## 7. Phoenix REST API + WebSocket for Protocol Management

Expose protocol state and operations via Phoenix controllers and channels:

### Router

```elixir
defmodule MyProtocol.Web.Router do
  use Phoenix.Router
  import Plug.Conn
  import Phoenix.Controller

  pipeline :api do
    plug :accepts, ["json"]
    plug MyProtocol.Web.Plugs.Auth
  end

  scope "/api", MyProtocol.Web do
    pipe_through :api
    get "/status", StatusController, :index
    get "/peers", PeersController, :index
    get "/messages", MessagesController, :index
    post "/messages", MessagesController, :create
  end
end
```

### Token-Based Auth Plug

```elixir
defmodule MyProtocol.Web.Plugs.Auth do
  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    tokens = Application.get_env(:my_protocol, :api_tokens)

    if tokens == nil or tokens == [] do
      conn  # dev mode: no tokens configured = allow all
    else
      case get_req_header(conn, "authorization") do
        ["Bearer " <> token] ->
          if token in tokens, do: conn, else: halt_unauthorized(conn)
        _ ->
          halt_unauthorized(conn)
      end
    end
  end

  defp halt_unauthorized(conn) do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(401, Jason.encode!(%{error: "Unauthorized"}))
    |> halt()
  end
end
```

**Pitfall:** `Application.get_env/3` with a default `[]` causes the plug to always allow requests (even when another test sets tokens). Use `Application.get_env/2` (no default) and check for `nil` explicitly.

**Pitfall:** Env var leaks between async tests. Always `Application.delete_env/2` in `setup` and restore in `on_exit` for any env that affects plug behavior.

### Status Controller

```elixir
defmodule MyProtocol.Web.StatusController do
  use Phoenix.Controller, formats: [:json]

  def index(conn, _params) do
    json(conn, %{
      node: "my_protocol",
      version: Application.spec(:my_protocol, :vsn) |> to_string(),
      uptime: :erlang.statistics(:wall_clock) |> elem(0) |> div(1000),
      links: safe_call(MyProtocol.LinkManager, :link_count, 0),
      paths: safe_call(MyProtocol.PathManager, :path_count, 0)
    })
  end

  defp safe_call(module, fun, default) do
    case Process.whereis(module) do
      nil -> default
      _pid -> apply(module, fun, [])
    end
  rescue
    _ -> default
  end
end
```

### WebSocket Channel

```elixir
defmodule MyProtocol.Web.PeersChannel do
  use Phoenix.Channel

  def join("peers:lobby", _payload, socket) do
    paths =
      case Process.whereis(MyProtocol.PathManager) do
        nil -> []
        _pid -> MyProtocol.PathManager.all_paths()
      end

    peers = Enum.map(paths, fn entry ->
      %{hash: Base.encode16(entry.destination_hash, case: :lower), hops: entry.hops}
    end)

    {:ok, %{peers: peers, count: length(peers)}, socket}
  end

  def handle_in("ping", _payload, socket) do
    {:reply, {:ok, %{pong: true, timestamp: System.system_time(:second)}}, socket}
  end
end
```

### Endpoint Wiring

```elixir
defmodule MyProtocol.Web.Endpoint do
  use Phoenix.Endpoint, otp_app: :my_protocol

  socket "/socket", MyProtocol.Web.UserSocket,
    websocket: true,
    longpoll: false

  plug MyProtocol.Web.Router
end
```

### Testing Router Directly

For controller tests without starting the full endpoint:

```elixir
defmodule MyProtocol.WebTest do
  use ExUnit.Case, async: true
  import Plug.Test
  import Plug.Conn

  alias MyProtocol.Web.Router
  @opts Router.init([])

  test "GET /api/status" do
    conn = conn(:get, "/api/status") |> Router.call(@opts)
    assert conn.status == 200
    body = Jason.decode!(conn.resp_body)
    assert body["node"] == "my_protocol"
  end
end
```

**Pitfall:** `use Plug.Test` is deprecated. Use `import Plug.Test` and `import Plug.Conn` instead.

## 8. Telemetry Integration

Add `:telemetry` events to all major operations for observability:

```elixir
defmodule MyProtocol.Telemetry do
  use Supervisor
  import Telemetry.Metrics

  def start_link(arg), do: Supervisor.start_link(__MODULE__, arg, name: __MODULE__)

  @impl true
  def init(_arg) do
    children = [
      {:telemetry_poller, measurements: periodic_measurements(), period: 10_000}
    ]
    Supervisor.init(children, strategy: :one_for_one)
  end

  def metrics do
    [
      counter("myproto.link.created.count"),
      counter("myproto.message.received.count"),
      last_value("myproto.system.memory.usage", unit: :byte)
    ]
  end

  defp periodic_measurements do
    [{__MODULE__, :collect_system_metrics, []}]
  end

  def collect_system_metrics do
    :telemetry.execute([:myproto, :system, :memory], %{usage: :erlang.memory(:total)}, %{})
  end

  # Helper emitters
  def link_created(link_id, meta \\ %{}), do:
    :telemetry.execute([:myproto, :link, :created], %{count: 1}, Map.put(meta, :link_id, link_id))

  def message_received(hash, meta \\ %{}), do:
    :telemetry.execute([:myproto, :message, :received], %{count: 1}, Map.put(meta, :hash, hash))
end
```

**Wire into Application supervisor:**

```elixir
children = [
  MyProtocol.Telemetry,
  MyProtocol.Web.Endpoint
]
```

**Pitfall:** `Telemetry.Metrics.Counter` and `Telemetry.Metrics.LastValue` structs are NOT available at compile time in controller modules that import the `Telemetry` module. Use pattern matching on `__struct__` instead:

```elixir
# WRONG — struct not available at compile time
 defp format_metric(%Telemetry.Metrics.Counter{name: name}) do

# CORRECT — match on __struct__ field
 defp format_metric(%{__struct__: struct, name: name})
      when struct in [Telemetry.Metrics.Counter, Telemetry.Metrics.Sum] do
```

## 9. Auth Plug Pitfalls

### `Application.get_env/3` Default Trap

```elixir
# WRONG — default [] means plug ALWAYS allows, even when another test sets tokens
 tokens = Application.get_env(:my_app, :api_tokens, [])
 if tokens == [] do

# CORRECT — no default, check for nil explicitly
 tokens = Application.get_env(:my_app, :api_tokens)
 if tokens == nil or tokens == [] do
```

### Test Isolation for Auth

Env var leaks between async tests. Always clean in `setup`:

```elixir
describe "auth" do
  setup do
    prev = Application.get_env(:my_app, :api_tokens)
    Application.delete_env(:my_app, :api_tokens)
    on_exit(fn ->
      if prev, do: Application.put_env(:my_app, :api_tokens, prev)
    end)
    :ok
  end
end
```

### Testing Router Directly (Without Endpoint)

For fast controller tests without starting the full Phoenix endpoint:

```elixir
defmodule MyApp.WebTest do
  use ExUnit.Case, async: true
  import Plug.Test
  import Plug.Conn

  alias MyApp.Web.Router
  @opts Router.init([])

  test "GET /api/status" do
    conn = conn(:get, "/api/status") |> Router.call(@opts)
    assert conn.status == 200
    body = Jason.decode!(conn.resp_body)
    assert body["node"] == "my_app"
  end
end
```

**Pitfall:** `use Plug.Test` is deprecated. Use `import Plug.Test` and `import Plug.Conn` instead.

**Pitfall:** Router tests bypass the endpoint's `render_errors` config and socket mounting. Auth plugs and content-type plugs still fire (they're in the router pipeline), but endpoint-level features are not exercised.

## Quality Gates

Every protocol change must pass:

```bash
mix compile          # 0 warnings
mix test             # all pass
mix format --check-formatted
mix credo            # 0 issues
mix dialyzer         # 0 errors
```

**CHANGELOG version tracking:** When a project has multiple shipped versions, document ALL of them. The `mix.exs` version must match the latest release.

```bash
# Check what changed between tags for accurate CHANGELOG entries
git log --oneline v0.2.0..v0.3.0
```

Common version drift in Elixir:
- `mix.exs` `@version` attribute lags behind git tags
- CHANGELOG only has the first version entry
- Git tags exist but CHANGELOG doesn't mention them

**Fix:** After tagging a release, immediately update CHANGELOG with the new section and bump `mix.exs` version.

## Related
- `elixir-crypto-debugging` — AEAD ciphers, X25519, HKDF, HMAC in Erlang `:crypto`
- `references/reticulum-protocol-constants.md` — Specific constants from Python RNS reference implementation
- `references/lxmf-protocol-constants.md` — LXMF message format, delivery methods, and propagation constants
