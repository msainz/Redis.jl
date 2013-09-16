using Redis
using Base.Test

client = redis()

@test get(client, "foo") == "4.53"

@test bgsave(client) == true

@test echo(client, "foo") == "foo"

@test flushall(client) == true

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
