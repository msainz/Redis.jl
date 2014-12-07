using Redis
using Base.Test
include("test_guard.jl")

client = redis()

@test flushall(client) == true
@test keys(client) == {}

@test lpushx(client, "_doesnt_exist_", "no thx") == 0

@test lpush(client, "spam", "eggs") == 1
@test lpush(client, "spam", "bacon") == 2
@test llen(client, "spam") == 2

@test lrange(client, "spam", 0, 2) == {"bacon", "eggs"}
@test lindex(client, "spam", 0) == "bacon"
@test lindex(client, "spam", 1) == "eggs"


@test linsert(client, "spam", "BEFORE", "eggs", "second") == 3
@test linsert(client, "spam", "BEFORE", "eggs", 3) == 4
@test lrange(client, "spam", 0, 4) == {"bacon", "second", "3", "eggs"}

@test lpop(client, "spam") == "bacon"
@test lrange(client, "spam", 0, 4) == {"second", "3", "eggs"}

@test lrem(client, "spam", 2, "second") == 1
@test lrange(client, "spam", 0, 4) == {"3", "eggs"}

@test lset(client, "spam", 0, "foo") == 1
@test lrange(client, "spam", 0, 4) == {"foo", "eggs"}

@test lpush(client, "spam", "bacon", "spam", "spam", "spam") == 6
@test ltrim(client, "spam", 3, 5) == true

@test lrange(client, "spam", 0, 10) == {"bacon", "foo", "eggs"}
