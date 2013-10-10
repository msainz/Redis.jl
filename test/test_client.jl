using Redis
using Base.Test

client = redis()

@test flushall(client) == true

@test set(client, "foo", 4; xx=true) == false
@test set(client, "foo", 4) == true
@test set(client, "foo", "bananas"; nx=true) == false
@test set(client, "foo", 4.53; xx=true) == true

@test get(client, "foo") == "4.53"

@test bgsave(client) == true

@test echo(client, "foo") == "foo"

@test flushdb(client) == true

@test dbsize(client) == 0

@show info(client)
@show info(client, "clients")

@test ping(client) == true

@test save(client) == true

@test bgrewriteaof(client) == true

@show time(client)

@test append(client, "foo", "123") == length("123")
@test append(client, "foo", "+45") == length("123+45")

@test flushall(client) == true
