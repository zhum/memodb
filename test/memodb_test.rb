# frozen_string_literal: true
Bundler.require(:development)

require 'test_helper'
Minitest::Reporters.use! [Minitest::Reporters::SpecReporter.new(color: true)]

describe Memo do
  Foo = Class.new do
    extend Memo

    def initialize
      @x = 0
      @y = 0
    end

    memo_db('./memo.db')
    memo_timeout(2)
    def inc
      @x += 1
    end

    def inc2
      @y += 2
    end
    memoize :inc
    memoize :inc2
  end

  before do
    @f = Foo.new
    @f.memo_reset
  end

  it 'caches' do
    # skip
    # initial increment 0->1
    _(@f.inc).must_equal(1)
    # read from cache
    _(@f.inc).must_equal(1)
  end

  it 'differ methods cache separated' do
    # skip
    # initial increment 0->1
    _(@f.inc).must_equal(1)
    # read from cache
    _(@f.inc2).must_equal(2)
  end

  it 'does not differ exemplars' do
    # skip
    @g = Foo.new
    # initial increment 0->1
    _(@f.inc).must_equal(1)
    @f.memo_reset('inc')
    _(@f.inc).must_equal(2)
    # print "\n1: ", Foo.actual_db, "\n"
    # another exemplar does read from cache
    _(@g.inc).must_equal(2)
    # print '2: ', Foo.actual_db, "\n"
  end

  it 'does reset' do
    # skip
    _(@f.inc).must_equal(1)
    # reset!
    @f.memo_reset('inc')
    # new increment
    _(@f.inc).must_equal(2)
  end

  it 'expire_cache' do
    # skip
    # read cache
    _(@f.inc).must_equal(1)
    # expire cache
    sleep(2.5)
    # new increment
    _(@f.inc).must_equal(2)
  end
end