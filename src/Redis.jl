module Redis

  export RedisException,
         AuthenticationError,
         ConnectionError,
         InvalidResponse

  export RedisCli, RedisParser, SimpleParser, Connection, ConnectionPool
  export connect, disconnect, send_command, read_response
  export get_connection, release, disconnect

  include("exceptions.jl")
  include("connection.jl")
  include("connection_pool.jl")
  include("client.jl")

end
