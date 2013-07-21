module Redis

  export RedisException,
         AuthenticationError,
         ConnectionError
  export Connection
  export connect, disconnect, send_command

  include("exceptions.jl")
  include("connection.jl")

end
