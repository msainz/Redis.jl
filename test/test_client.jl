using Redis
using Base.Test

client = redis()

@test flushall(client) == true

@test exists(client, "foo") == false
@test dump(client, "foo") == nothing

@test set(client, "foo", 4; xx=true) == false
@test set(client, "foo", 4) == true
@test set(client, "foo", "bananas"; nx=true) == false
@test set(client, "foo", 4.53; xx=true) == true
@test get(client, "foo") == "4.53"
@test exists(client, "foo") == true

# dump and restore
@test exists(client, "goo") == false
@test restore(client, "goo", 100, dump(client, "foo")) == true
@test get(client, "goo") == "4.53"
sleep(0.150)
@test exists(client, "goo") == false
@test restore(client, "goo", 0, dump(client, "foo")) == true
@test get(client, "goo") == "4.53"

# key expiration via px (in milliseconds)
@test set(client, "foo", 4; px=500) == true
@test get(client, "foo") == "4"
sleep(0.510)
@test get(client, "foo") == nothing

# key expiration via ex (in seconds)
@test set(client, "foo", 4; ex=1) == true
@test get(client, "foo") == "4"
sleep(1.1)
@test get(client, "foo") == nothing

@test bgsave(client) == true

@test echo(client, "foo") == "foo"

@test flushdb(client) == true

@test dbsize(client) == 0

dict = info(client)
@test typeof( dict ) == Dict{Any, Any}
@test length(dict) > 0
dict = info(client, "clients")
@test typeof( dict ) == Dict{Any, Any}
@test length(dict) > 0

@test ping(client) == true

@test save(client) == true

@test bgrewriteaof(client) == true

@test typeof( time(client) ) == (Int, Int)

@test append(client, "foo", 123) == length("123")
@test append(client, "foo", "+45") == length("123+45")

@test flushall(client) == true
