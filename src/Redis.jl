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
           info, ping, save, time

    #### BASIC KEY COMMANDS ####
    export keys, append, exists, dump, restore, get, set, del,
                 incr, decr

    #### LISTS ####
    export lindex, linsert, llen, lpop, lpush,
           lpushx, lrange, lrem, lset, ltrim

    #### SETS ####
    export sadd, smove, scard, spop, sdiff, srandmember, sdiffstore,
           srem, sinter, sunion, sinterstore, sunionstore, sismember,
           sscan, smembers

    include("exceptions.jl")
    include("connection.jl")
    include("connection_pool.jl")
    include("client.jl")

end
