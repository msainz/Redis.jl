# Core exceptions raised by the Redis client


abstract RedisError <: Exception


type AuthenticationError <: RedisError
  message::ASCIIString
end


type ServerError <: RedisError
end


type ConnectionError <: RedisError # <: ServerError
  message::ASCIIString
end


type BusyLoadingError <: RedisError # <: ConnectionError
end


type InvalidResponse <: RedisError # <: ServerError
end


type ResponseError <: RedisError
end


type DataError <: RedisError
end


type PubSubError <: RedisError
end


type WatchError <: RedisError
end


type NoScriptError <: RedisError # <: ResponseError
end


type ExecAbortError <: RedisError # <: ResponseError
end

