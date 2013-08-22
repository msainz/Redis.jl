type ConnectionPool
  # It maintains a pool of reusable connections that can be shared by
  # multiple redis clients (TODO: safely across threads)
  pid::Int32
  max_connections::Integer
  connection_args::Vector{Any}
  created_connections::Integer
  available_connections::Vector{Connection}
  in_use_connections::Set{Connection}

  function ConnectionPool(; max_connections=typemax(Int), connection_args...)
    new(
      getpid(),
      max_connections,
      connection_args,
      0,
      Array(Connection,0),
      Set{Connection}() )
  end

end # type ConnectionPool

function _checkpid(pool::ConnectionPool)
  # Reset the pool if called from another process
  pool.pid == getpid() && return
  disconnect(pool)
  pool.pid = getpid()
  pool.created_connections = 0
  pool.available_connections = Array(Connection,0)
  pool.in_use_connections = Set{Connection}()
  nothing
end

function get_connection(pool::ConnectionPool)
  # Get a connection from the pool
  _checkpid(pool)
  conn =
    if 0 < size(pool.available_connections,1)
      pop!(pool.available_connections)
    else
      make_connection(pool)
    end
  push!(pool.in_use_connections, conn)
  conn
end

function make_connection(pool::ConnectionPool)
  # Make a new connection
  # In the event that a client tries to get a connection from the pool
  # when all of connections are in use, it throws a ConnectionError
  if pool.created_connections >= pool.max_connections
    throw(ConnectionError("Too many connections"))
  else
    pool.created_connections += 1
  end
  Connection(; pool.connection_args...)
end

function release(pool::ConnectionPool, conn::Connection)
  # Releases the connection back to the pool
  _checkpid(pool)
  if conn.pid == pool.pid && contains(pool.in_use_connections, conn)
    delete!(pool.in_use_connections, conn)
    push!(pool.available_connections, conn)
  end
  nothing
end

function disconnect(pool::ConnectionPool)
  # Disconnects all connections in the pool
  for conn in pool.in_use_connections
    disconnect(conn)
  end
  for conn in pool.available_connections
    disconnect(conn)
  end
  nothing
end
