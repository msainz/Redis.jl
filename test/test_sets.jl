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
# Result is not cast to set by default because values are returned in order
@test Set(smembers(client, "eggs_words_union")) == Set({"10", "brian", "no", "yes"})

@test sinterstore(client, "inter_eggs", "eggs_words_union", "eggs") == 2
@test Set(smembers(client, "inter_eggs")) == Set({"10", "brian"})

@test Set(sunion(client, "languages", "words")) == Set({"python","no","julia","yes"})
@test sinter(client, "inter_eggs", "words") == {}
@test Set(sinter(client, "inter_eggs", "inter_eggs")) == Set({"10", "brian"})

@test srem(client, "inter_eggs", "brian") == 1
@test smembers(client, "inter_eggs") == {"10"}

@test sdiffstore(client, "diff", "eggs", "inter_eggs") == 1
@test smembers(client, "diff") == {"brian"}

@test srandmember(client, "diff", 1) == {"brian"}
@test sdiff(client, "eggs", "diff") == {"10"}

@test spop(client, "diff") == "brian"
@test scard(client, "diff") == 0
@test scard(client, "eggs") == 2

@test smove(client, "eggs", "diff", "10") == 1
@test scard(client, "diff") == 1
@test scard(client, "eggs") == 1

@test sadd(client, "scan_me", 0, 1, 10, 101, 1001, 4, 3, 2, 1) == 8
@test Set(sscan(client, "scan_me", 0)) == 
    Set({"0", {"0", "1", "2", "3", "4", "10", "101", "1001"}})
@test Set(sscan(client, "scan_me", 0, match="1*")) == 
    Set({"0", {"1", "10", "101", "1001"}})
