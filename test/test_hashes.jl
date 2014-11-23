using Redis
using Base.Test
include("test_guard.jl")

client = redis()

@test flushall(client) == true
@test keys(client) == {}

@test hset(client, "foo", "bar", 10) == 1
@test hset(client, "foo", "bar", 10) == 0
@test hexists(client, "foo", "bar") == true

@test hvals(client, "foo") == {"10"}
@test hget(client, "foo", "bar") == "10"

@test hdel(client, "foo", "bar") == 1
@test hgetall(client, "foo") == Dict{Any, Any}()

@test hset(client, "foo", "hash", "yes") == 1
@test hset(client, "foo", "list", "yes") == 1
@test hgetall(client, "foo", to_dict=false) == {"hash", "yes", "list", "yes"}
@test hgetall(client, "foo") == {"list"=>"yes", "hash" => "yes"}

@test hincrby(client, "spam", "eggs", 1) == 1
@test hgetall(client, "spam") == {"eggs" => "1"}

@test hincrby(client, "spam", "eggs", 2) == 3
@test hgetall(client, "spam") == {"eggs" => "3"}

@test hincrbyfloat(client, "spam", "eggs", 1.5) == 4.5
@test hgetall(client, "spam") == {"eggs" => "4.5"}

@test hkeys(client, "spam") == {"eggs"}

@test hlen(client, "foo") == 2
@test hlen(client, "spam") == 1

@test hmset(client, "set_this_things",
    {1 => 2, "a" => "b", "y" => "z", "10" => "100"}) == true
@test hgetall(client, "set_this_things") ==
    {"1" => "2", "a" => "b", "y" => "z", "10" => "100"}

@test hmget(client, "set_this_things", ["1", "a", "10"]...) == {"2", "b", "100"}

@test hsetnx(client, "set_this_things", "778899", 0) == 1
@test hsetnx(client, "set_this_things", "778899", 5) == 0

@test hget(client, "set_this_things", "778899") == "0"

@test hscan(client, "set_this_things", 0) == 
    {"0", {"1"=> "2", "778899"=> "0", "10"=> "100", "a"=> "b", "y"=> "z"}}

@test hmset(client, "scan_me",
    {"foo" => 0, "bar" => 1, "fig" => 0, "eggs" => 1, "fork" => 0}) == true

@test hscan(client, "scan_me", 0, match="f*") ==
    {"0", {"fig"=> "0", "fork"=> "0", "foo"=> "0"}}
