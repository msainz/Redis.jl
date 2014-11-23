using Redis
using Base.Test
include("test_guard.jl")

client = redis()

@test flushall(client) == true
@test keys(client) == {}

@test sadd(client, "eggs", 10) == 1
@test sadd(client, "eggs", "brian") == 1

@test smembers(client, "eggs") == {"brian", "10"}
@test sismember(client, "eggs", "brian") == true

@test sadd(client, "words", "yes", "no") == 2
@test sadd(client, "languages", "python", "julia") == 2

@test sunionstore(client, "eggs_words_union", "eggs", "words") == 4
@test smembers(client, "eggs_words_union") == {"no", "brian", "yes", "10"}

@test sinterstore(client, "inter_eggs", "eggs_words_union", "eggs") == 2
@test smembers(client, "inter_eggs") == {"brian", "10"}

# Result is not cast to set by default because values are returned in order
@test Set(sunion(client, "languages", "words")) == Set({"python","no","julia","yes"})
@test sinter(client, "inter_eggs", "words") == {}
@test sinter(client, "inter_eggs", "inter_eggs") == {"brian", "10"}

@test srem(client, "inter_eggs", "brian") == 1
@test smembers(client, "inter_eggs") == {"10"}
