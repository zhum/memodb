# frozen_string_literal: true

# Bundler.require(:default)
require 'sqlite3'

##
## Module for memoize methods return values. It can save memoized data into
## sqlite database.
## **IMPORTANT!** It does **not** differ exemplars and caches values only by
## method name!
##
## Example code:
##    require 'memodb'
##    class MyTest
##      extend Memo
##      memo_db('/tmp/my_cache.db')  # path to cache database
##      memo_timeout(10)             # cache timeout = 10 seconds
##      def initialize; @x = 0; end
##      def mymethod
##        @x += 1
##      end
##      def brute_method
##        @x += 1
##      end
##      memoize :mymethod            # cache this method results
##    end
##
##    t = MyTest.new
##    puts t.mymethod    # => 1
##    puts t.mymethod    # => 1
##    MyTest.memo_reset :mymethod
##    puts t.mymethod    # => 2
##    puts t.brute_method # => 3  # not cached
## @author     Sergey Zhumatiy (serg@parallel.ru)
module Memo
  ##
  ## Specify cache database path.
  ## If no path specified, returns current path if any.
  ##
  ## @param      filename  The filename
  ## @return     path to current database
  ##
  def memo_db(filename = nil)
    if filename
      @db = ::SQLite3::Database.new filename
      @db.execute 'CREATE TABLE IF NOT EXISTS memo(method TEXT, tmout INT, args BLOB, result BLOB, PRIMARY KEY (method, args))'
    end
    @db
  end

  ##
  ## Returns text representstion of current database and cache
  ## "method;timeout;args;value\n... // cache"
  ##
  ## @return     [String] text
  ##
  def actual_db
    db = memo_db
    a = []
    db && db.query('select * from memo') do |res|
      a = res.map{ |r| "#{r[0]};#{r[1]};#{Marshal.load(r[2])};#{Marshal.load(r[3])}i"}.join("\n")
      a += "//#{memoize_cache.inspect}"
    end
    a
  end

  ##
  ## Set cache timeout
  ##
  ## @param     [Number] tmout  The timeout
  ##
  def memo_timeout(tmout)
    @memoize_timeout = tmout
  end

  ##
  ## Raw cache
  ##
  ## @return     [Hash] The cache
  ##
  def memoize_cache
    @memoize_cache ||= {}
  end

  ##
  ## Current cache timeout
  ##
  ## @return     [Integer] timeout
  ##
  def memoize_timeout
    @memoize_timeout || 1_000_000
  end

  ##
  ## Reset cache for one or all methods
  ##
  ## @param      [String|nil] method_name  The method name
  ##
  def memo_reset(method_name = nil)
    db = memo_db
    cache = memoize_cache
    if method_name
      cache.delete_if { |k, _| k[0].to_s == method_name }
      db && db.execute(
        'DELETE FROM memo WHERE method = ?',
        method_name.to_s
      )
    else
      cache.clear
      db && db.execute('DELETE FROM memo')
    end
    db && db.execute('VACUUM')
  end

  ##
  ## Do cache this method
  ##
  ## @param      [Symbol] method_name  The method name
  ##
  def memoize(method_name)
    alias_method "_memoized_#{method_name}", method_name

    define_method method_name do |*args|
      key = [method_name, args]
      now = Time.now.to_i
      cache = self.class.memoize_cache

      if cache.key?(key)
        # in cache
        # print "1: #{cache[key]} (#{key})\n"
        return cache[key] if memo_tmout(method_name) > now
      else
        # try to load from db
        memo_from_db(method_name, args)
        # print "2: #{cache[key]} (#{key})\n"
        return cache[key] if cache[key] && memo_tmout(method_name) > now
      end
      # not in cache
      memo_tmout_set(method_name, self.class.memoize_timeout + now)
      cache[key] = val = send("_memoized_#{method_name}", *args)
      memo_save_db(method_name, val, now, args)
      # print "3: #{val} (#{key})\n"
      val
    end
    memo_declare_methods
  end

  private
  def memo_declare_methods
    @@memo_declared ||= false
    return if @@memo_declared
    @@memo_declared = true
    # define_method 'memo_from_db' do |method_name, args|
    define_method 'memo_from_db' do |method_name, args|
      db = self.class.memo_db
      if db
        db.query('select * from memo where method = ? and args = ?', [method_name.to_s, Marshal.dump(args)]) do |res|
          cache = self.class.memoize_cache
          res.each do |row|
            cache[[method_name.to_sym, args]] = Marshal.restore(row[3])
            memo_tmout(row[1])
            # print "CACHE: #{cache.inspect}, tmout=#{row[1]}\n"
          end
        end
      end
    end

    define_method 'memo_save_db' do |method_name, value, now, args|
      db = self.class.memo_db
      db && db.execute(
        'INSERT OR REPLACE INTO memo (method, tmout, args, result) VALUES (?, ?, ?, ?)', [
          method_name.to_s, now + self.class.memoize_timeout,
          Marshal.dump(args), Marshal.dump(value)
        ]
      )
    end

    define_method 'memo_reset' do |*method_name|
      self.class.memo_reset method_name[0]
    end

    define_method 'memo_tmout' do |method|
      @@memo_tmout_time ||= {}
      @@memo_tmout_time[method] || 0
    end

    define_method 'memo_tmout_set' do |method, val|
      @@memo_tmout_time ||= {}
      @@memo_tmout_time[method] = val
    end
  end
end
