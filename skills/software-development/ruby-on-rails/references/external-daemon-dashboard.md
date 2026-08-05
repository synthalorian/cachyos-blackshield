# External Daemon Dashboard Pattern

Reference: Reticulum Hub session (2026-05-31) — Rails 8 dashboard for Reticulum mesh network management.

## Problem

Build a Rails web dashboard that connects to an external daemon (rnsd) via TCP/Unix socket. The daemon may not be running during development, testing, or demos. The dashboard must remain fully functional with realistic mock data.

## Architecture

```
Browser ←→ Rails App ←→ RnsAdapter ←→ [TCP/Unix Socket] ←→ rnsd (optional)
                ↓
           Mock Data Fallback
```

## Service Object Pattern

```ruby
# app/services/rns_adapter.rb
class RnsAdapter
  DEFAULT_TCP_HOST = "127.0.0.1"
  DEFAULT_TCP_PORT = 3742
  DEFAULT_SOCKET_PATH = "~/.reticulum/rnsd.sock"

  class ConnectionError < StandardError; end

  def initialize(host: nil, port: nil, socket_path: nil)
    @host = host || ENV.fetch("RNSD_HOST", DEFAULT_TCP_HOST)
    @port = port || ENV.fetch("RNSD_PORT", DEFAULT_TCP_PORT).to_i
    @socket_path = File.expand_path(socket_path || ENV.fetch("RNSD_SOCKET", DEFAULT_SOCKET_PATH))
    @connected = false
    @mutex = Mutex.new
  end

  def connected?; @connected; end

  def connect
    @mutex.synchronize do
      if File.exist?(@socket_path)
        @socket = UNIXSocket.new(@socket_path)
      else
        @socket = TCPSocket.new(@host, @port)
      end
      @connected = true
    end
    true
  rescue => e
    Rails.logger.warn "RnsAdapter: could not connect (#{e.message})"
    @connected = false
    false
  end

  def disconnect
    @mutex.synchronize do
      @socket&.close
      @socket = nil
      @connected = false
    end
  end

  # Every public method: try real connection, fall back to mock
  def peers
    return mock_peers unless connected?
    response = send_command("peers")
    parse_peers(response)
  rescue ConnectionError
    mock_peers
  end

  def interfaces
    return mock_interfaces unless connected?
    response = send_command("interfaces")
    parse_interfaces(response)
  rescue ConnectionError
    mock_interfaces
  end

  private

  def send_command(cmd, params = {})
    raise ConnectionError, "Not connected" unless @socket
    request = { command: cmd, params: params }.to_json
    @socket.puts(request)
    response = @socket.gets
    raise ConnectionError, "No response" unless response
    JSON.parse(response)
  rescue JSON::ParserError => e
    Rails.logger.error "RnsAdapter: JSON parse error (#{e.message})"
    { "status" => "error", "message" => e.message }
  rescue Errno::EPIPE, Errno::ECONNRESET, IOError => e
    @connected = false
    raise ConnectionError, e.message
  end

  # Mock data — rich enough for views to render
  def mock_peers
    [
      { destination_hash: "<f0a1b2c3>", name: "Field Node Alpha",
        last_seen: 2.minutes.ago, link_quality: 0.92, hops: 1, status: "active" },
      { destination_hash: "<d4e5f6a7>", name: "Base Station",
        last_seen: 30.seconds.ago, link_quality: 0.98, hops: 0, status: "active" },
    ]
  end

  def mock_interfaces
    [
      { name: "AutoInterface", interface_type: "AutoInterface", status: "up",
        bandwidth_in: 1_240_000, bandwidth_out: 890_000, error_rate: 0.001, uptime: 86400 },
    ]
  end

  def parse_peers(response); response["peers"] || []; end
  def parse_interfaces(response); response["interfaces"] || []; end
end
```

## Controller Pattern: Hash-to-Model Mapping

When the adapter returns hashes with nested association data, **do not** pass to `Model.new(hash)`:

```ruby
# WRONG — AssociationTypeMismatch on nested hashes
@nodes = rns.nodes.map { |n| Node.new(n) }

# CORRECT — find_or_initialize_by + assign_attributes with except
@nodes = rns.nodes.map do |n|
  node = Node.find_or_initialize_by(destination_hash: n[:destination_hash])
  node.assign_attributes(n.except(:services))  # Skip nested data
  node
end
```

## Background Polling Job

```ruby
# app/jobs/rns_poll_job.rb
class RnsPollJob < ApplicationJob
  queue_as :default

  def perform
    rns = RnsAdapter.new
    rns.connect

    # Sync peers to database
    rns.peers.each do |peer_data|
      Peer.find_or_initialize_by(destination_hash: peer_data[:destination_hash]).tap do |peer|
        peer.assign_attributes(peer_data)
        peer.save!
      end
    end

    # Sync interfaces
    rns.interfaces.each do |iface_data|
      Interface.find_or_initialize_by(name: iface_data[:name]).tap do |iface|
        iface.assign_attributes(iface_data)
        iface.save!
      end
    end

    # Record stats
    stats = rns.system_stats
    SystemStat.create!(stats)

    # Broadcast updates
    NetworkChannel.broadcast_update({
      type: "network_update",
      peers: rns.peers,
      interfaces: rns.interfaces,
      stats: stats,
      timestamp: Time.current.iso8601
    })
  rescue => e
    Rails.logger.error "RnsPollJob failed: #{e.message}"
  end
end
```

## Recurring Schedule

```yaml
# config/recurring.yml
production:
  rns_poll:
    class: RnsPollJob
    queue: default
    schedule: every 5 seconds
```

## Key Principles

1. **Every adapter method has mock fallback** — `return mock_data unless connected?`
2. **Connection errors bubble up as `ConnectionError`** — caught by caller, returns mock
3. **Mock data is realistic** — real types (Time, Float, Integer), enough fields for views
4. **Controller maps hashes to AR safely** — `find_or_initialize_by` + `assign_attributes(n.except(:nested))`
5. **Polling job syncs to DB + broadcasts** — database is source of truth, WebSocket pushes updates
6. **Recurring schedule in YAML** — Solid Queue reads `config/recurring.yml` automatically
