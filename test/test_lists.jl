using Redis
using Base.Test
include("test_guard.jl")

client = redis()

@test flushall(client) == true
@test keys(client) == {}

@test lpush(client, "spam", "eggs") == 1
@test lpush(client, "spam", "bacon") == 2
@test llen(client, "spam") == 2

@test lrange(client, "spam", 0, 2) == {"bacon", "eggs"}
@test lindex(client, "spam", 0) == "bacon"
@test lindex(client, "spam", 1) == "eggs"


@test linsert(client, "spam", "BEFORE", "eggs", "second") == 3
@test linsert(client, "spam", "BEFORE", "eggs", 3) == 4

@test lrange(client, "spam", 0, 4) == {"bacon", "second", "3", "eggs"}
