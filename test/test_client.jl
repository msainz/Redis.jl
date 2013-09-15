using Redis
using Base.Test

client = redis()

@test execute_command(client, "GET", "foo") == "4.53"

@test bgsave(client) == true

@test echo(client, "foo") == "foo"

@test flushall(client) == true

@test flushdb(client) == true

@test dbsize(client) == 0

@show info(client)
@show info(client, "clients")

@test bgrewriteaof(client) == true

