
function string_keys_to_dict(keys::ASCIIString, callback::Function)
  keys_arr = convert(Array{ASCIIString}, split(keys)) # split returns Array{String}
  vals_arr = repeat([callback]; inner = [length(keys_arr)])
  Dict(keys_arr, vals_arr)
end

const RESPONSE_CALLBACKS = merge(
  string_keys_to_dict(
    "AUTH EXISTS EXPIRE EXPIREAT HEXISTS HMSET MOVE MSETNX PERSIST " *
    "PSETEX RENAMENX SISMEMBER SMOVE SETEX SETNX",
    bool
  ),
  string_keys_to_dict(
    "BITCOUNT DECRBY DEL GETBIT HDEL HLEN INCRBY LINSERT LLEN LPUSHX " *
    "RPUSHX SADD SCARD SDIFFSTORE SETBIT SETRANGE SINTERSTORE SREM " *
    "STRLEN SUNIONSTORE ZADD ZCARD ZREM ZREMRANGEBYRANK " *
    "ZREMRANGEBYSCORE",
    int
  ),
  {
    "BGREWRITEAOF" => (r) -> ismatch(r"rewriting started", r),
    "BGSAVE" => (r) -> ismatch(r"saving started", r)
  }
)

type RedisClient
  # Implementation of the Redis protocol
  # http://redis.io/topics/protocol
  #
  # This type abstracts a julia interface to all Redis commands
  # and an implementation of the Redis protocol.
  #
  # Connection and Pipeline implement how the commands are sent
  # and received to and from the Redis server
  connection_pool::ConnectionPool
  response_callbacks::Dict{ASCIIString, Function}
end # type RedisClient

function redis(; host="localhost", port=6379, db=0, password=nothing,
                 connection_pool=nothing, charset="utf-8")
  if connection_pool==nothing
    kvargs = [
      :host => host,
      :port => port,
      :db => db,
      :password => password
      # TODO: :encoding => charset
    ]
    connection_pool = ConnectionPool(; kvargs...)
  end
  RedisClient(connection_pool, RESPONSE_CALLBACKS) # TODO: (deep)copy RESP_CALLBKS?
end

#### COMMAND EXECUTION AND PROTOCOL PARSING ####

function execute_command(client::RedisClient, args...; options...)
  # Execute a command and return a parsed response
  pool = client.connection_pool
  command_name = args[1]
  connection = get_connection(pool)
  try
    send_command(connection, args...)
    return parse_response(client, connection, command_name; options...)
  catch err
    @show err
    if isa(err, ConnectionError)
      disconnect(connection)
      send_command(connection, command_name; options...)
      return parse_response(client, connection, command_name; options...)
    end
  finally
    release(pool, connection)
  end
end

function parse_response(client::RedisClient, conn::Connection,
                        command_name::ASCIIString; options...)
  # Parses a response from the Redis server
  response = read_response(conn)
  if in(command_name, keys(client.response_callbacks))
    return client.response_callbacks[command_name](response, options...)
  end
  response
end

#### SERVER INFORMATION COMMANDS ####
function bgrewriteaof(client::RedisClient)
  # Tell the Redis server to rewrite the AOF file from data in memory.
  execute_command(client, "BGREWRITEAOF")
end

# function bgsave(client::RedisClient)
  # # Tell the Redis server to save its data to disk.  Unlike save(),
  # # this method is asynchronous and returns immediately.
  # execute_command(client, "BGSAVE")
# end

# function client_kill(self, address)
  # # Disconnects the client at ``address`` (ip:port)
  # return self.execute_command('CLIENT', 'KILL', address, parse='KILL')
# end

# function client_list(self)
  # # Returns a list of currently connected clients
  # return self.execute_command('CLIENT', 'LIST', parse='LIST')
# end

# function client_getname(self)
  # # Returns the current connection name
  # return self.execute_command('CLIENT', 'GETNAME', parse='GETNAME')
# end

# function client_setname(self, name)
  # # Sets the current connection name
  # return self.execute_command('CLIENT', 'SETNAME', name, parse='SETNAME')
# end

# function config_get(self, pattern="*")
  # # Return a dictionary of configuration based on the ``pattern``
  # return self.execute_command('CONFIG', 'GET', pattern, parse='GET')
# end

# function config_set(self, name, value)
  # # Set config item ``name`` with ``value``
  # return self.execute_command('CONFIG', 'SET', name, value, parse='SET')
# end

# function config_resetstat(self)
  # # Reset runtime statistics
  # return self.execute_command('CONFIG', 'RESETSTAT', parse='RESETSTAT')
# end

# function dbsize(self)
  # # Returns the number of keys in the current database
  # return self.execute_command('DBSIZE')
# end

# function debug_object(self, key)
  # # Returns version specific metainformation about a give key
  # return self.execute_command('DEBUG', 'OBJECT', key)
# end

# function echo(self, value)
  # # Echo the string back from the server
  # return self.execute_command('ECHO', value)
# end

# function flushall(self)
  # # Delete all keys in all databases on the current host
  # return self.execute_command('FLUSHALL')
# end

# function flushdb(self)
  # # Delete all keys in the current database
  # return self.execute_command('FLUSHDB')
# end

# function info(self, section=None)
  # # Returns a dictionary containing information about the Redis server.
  # # The ``section`` option can be used to select a specific section
  # # of information
  # # The section option is not supported by older versions of Redis Server,
  # # and will generate ResponseError
  # if section is None:
      # return self.execute_command('INFO')
  # else:
      # return self.execute_command('INFO', section)
# end

# function lastsave(self)
  # # Return a Python datetime object representing the last time the
  # # Redis database was saved to disk
  # return self.execute_command('LASTSAVE')
# end

# function object(self, infotype, key)
  # # Return the encoding, idletime, or refcount about the key
  # return self.execute_command('OBJECT', infotype, key, infotype=infotype)
# end

# function ping(self)
  # # Ping the Redis server
  # return self.execute_command('PING')
# end

# function save(self)
  # # Tell the Redis server to save its data to disk,
  # # blocking until the save is complete
  # return self.execute_command('SAVE')
# end

# function sentinel(self, *args)
  # # Redis Sentinel's SENTINEL command
  # if args[0] in ['masters', 'slaves', 'sentinels']:
      # parse = 'SENTINEL_INFO'
  # else:
      # parse = 'SENTINEL'
  # return self.execute_command('SENTINEL', *args, **{'parse': parse})
# end

# function shutdown(self)
  # # Shutdown the server
  # try:
      # self.execute_command('SHUTDOWN')
  # except ConnectionError:
      # # a ConnectionError here is expected
      # return
  # raise RedisError("SHUTDOWN seems to have failed.")
# end

# function slaveof(self, host=None, port=None)
  # # Set the server to be a replicated slave of the instance identified
  # # by the ``host`` and ``port``. If called without arguements, the
  # # instance is promoted to a master instead.
  # if host is None and port is None:
      # return self.execute_command("SLAVEOF", "NO", "ONE")
  # return self.execute_command("SLAVEOF", host, port)
# end

# function time(self)
  # # Returns the server time as a 2-item tuple of ints:
  # # (seconds since epoch, microseconds into this second).
  # return self.execute_command('TIME')
# end

