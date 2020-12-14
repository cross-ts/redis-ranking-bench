#!/usr/bin/env ruby
# frozen_string_literal: true

require 'redis'
require 'benchmark/ips'

p 'wait for redis start'
sleep 3

class Ranking
  attr_accessor :id, :score, :rank
  def initialize(id, score)
    self.id = id
    self.score = score
  end

  def to_s
    "id: #{id}, score: #{score}, rank: #{rank.value + 1}"
  end
end

client = Redis.new(
  host: ENV.fetch('REDIS_HOST', 'localhost'),
  port: ENV.fetch('REDIS_PORT', 6379).to_i,
  driver: :hiredis
)

key = 'ranking'
data_size = 10_000

client.del(key)
client.pipelined do
  data_size.times do |i|
    client.zadd(key, rand(1..data_size), i)
  end
end

rankings = client.zrevrange(key, 0, 9, with_scores: true).map { |r| Ranking.new(*r) }

puts "Ranking DataSize: #{client.zcount(key, '-inf', '+inf')}"

Benchmark.ips do |x|
  x.config(time: 5, warmup: 2)
  x.report('pipelined + multi') do
    client.pipelined do
      client.multi do
        rankings.each { |r| r.rank = client.zcount(key, r.score + 1, '+inf') }
      end
    end
  end
  x.report('pipelined') do
    client.pipelined do
      rankings.each { |r| r.rank = client.zcount(key, r.score + 1, '+inf') }
    end
  end
  x.report('multi') do
    client.multi do
      rankings.each { |r| r.rank = client.zcount(key, r.score + 1, '+inf') }
    end
  end
  x.report('none') do
    rankings.each { |r| r.rank = client.zcount(key, r.score + 1, '+inf') }
  end
  x.compare!
end
