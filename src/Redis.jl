module Redis

  export RedisException,
         AuthenticationError,
         ConnectionError,
         InvalidResponse

  export RedisParser, SimpleParser, Connection, ConnectionPool
  export connect, disconnect, send_command, read_response
  export get_connection, release, disconnect
  export redis

  ### SERVER INFORMATION COMMANDS ###
  export bgrewriteaof, bgsave, dbsize, echo, flushall, flushdb,
         info

  # TODO: remove these -- temporary only
  export execute_command

  include("exceptions.jl")
  include("connection.jl")
  include("connection_pool.jl")
  include("client.jl")

end
