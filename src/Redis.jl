module Redis

  export RedisException,
         AuthenticationError,
         ConnectionError,
         InvalidResponse
  export Connection
  export connect, disconnect, send_command, read_response

  include("exceptions.jl")
  include("connection.jl")

end
