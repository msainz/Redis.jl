module Redis

  export RedisException,
         ConnectionError
  export Connection
  export connect

  include("exceptions.jl")
  include("connection.jl")

end
