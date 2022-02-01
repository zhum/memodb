# frozen_string_literal: true

require 'test_helper'

# class MemodbTest < Minitest::Test
#   def test_that_it_has_a_version_number
#     refute_nil ::Memodb::VERSION
#   end

#   def test_it_does_something_useful
#     assert false
#   end
# end

describe MemoDB do
  Foo = Class.new do
    include MemoDB

    def initialize
      @x = 0
    end

    memo_db('./memo.db')
    memo_timeout(1)
    memoized
    def inc
      @x += 1
    end
  end

  before do
    @f = Foo.new
  end

  it 'has_version' do
    refute_nil ::MemoDB::VERSION
  end

  it 'caches' do
    # initial increment 0->1
    _(@f.inc).must_equal(1)
    # read from cache
    _(@f.inc).must_equal(1)
  end

  it 'does reset' do
    _(@f.inc).must_equal(1)
    # reset!
    @f.memo_reset('inc')
    # new increment
    _(@f.inc).must_equal(2)
  end

  it 'expire_cache' do
    # read cache
    _(@f.inc).must_equal(1)
    # expire cache
    sleep(2)
    # new increment
    _(@f.inc).must_equal(2)
  end
end
