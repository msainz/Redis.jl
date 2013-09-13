using Redis
using Base.Test

client = redis()
@test execute_command(client, "GET", "foo") == "4.53"
@test bgrewriteaof(client) == true
# @test bgsave(client) == true
