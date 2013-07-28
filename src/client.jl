type RedisCli
  # Implementation of the Redis protocol
  # http://redis.io/topics/protocol
  #
  # This type abstracts a julia interface to all Redis commands
  # and an implementation of the Redis protocol.
  #
  # Connection and Pipeline implement how the commands are sent
  # and received to and from the Redis server
  connection_pool::Union(Nothing,ConnectionPool) # todo
  response_callbacks::Dict
  function RedisCli(; host="localhost", port=6379, db=0, password=nothing,
                   connection_pool=nothing, charset="utf-8")
    if connection_pool==nothing
      # todo
    end
    new(connection_pool, Dict())
  end
end
