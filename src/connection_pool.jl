type ConnectionPool
  # Generic connection pool
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
  return
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
  add!(pool.in_use_connections, conn)
  conn
end

function make_connection(pool::ConnectionPool)
  # Make a new connection
  if pool.created_connections >= pool.max_connections
    throw(ConnectionError("Too many connections"))
  else
    pool.created_connections += 1
  end
  Connection(; pool.connection_args...)
end

function release(pool::ConnectionPool, conn::Connection)
  # Releases the connection back to the pool

end

function disconnect(pool::ConnectionPool)
  # Disconnects all connections in the pool

end
