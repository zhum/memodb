# frozen_string_literal: true

require 'sqlite3'

module MemoDB
  class Memoizer
    attr_reader :context, :method

    def initialize(context, method, timeout, db)
      @context = context
      @method = method
      @timeout = timeout || 1_000_000
      @last = 0
      @db = db
    end

    def call(*args, &block)
      now = Time.now.to_i
      # print "---> #{@last} + #{@timeout} < #{now}\n"
      if (@last > 0) && (@last + @timeout > now) # not expired
        # print "CACHED: #{@last} + #{@timeout} < #{now}"
        return cache[args] if cache.key?(args)
      end
      # print "===> do call\n"
      @last = now
      result = context.send(method, *args, &block)
      @db && @db.execute(
        'INSERT INTO memo (method, last, args, result) VALUES (?, ?, ?, ?)', [
          @method.to_s, @last,
          Marshal.dump(args).to_s, Marshal.dump(result).to_s
        ]
      )
      # print "RES #{result}\n"
      cache[args] = result
    end

    def cache
      # print "CACHE0: #{@cache.inspect}\n"
      return @cache if @cache
      @cache = {}
      if @db
        @db.query("select * from memo where method = \"#{@method}\"") do |res|
          res.each do |row|
            @cache[Marshal.restore(row[2])] = Marshal.restore(row[3])
            @last = row[1]
            # print "CACHE1(#{method}): #{row.inspect}\n"
          end
        end
      end
      # print "CACHE: #{@cache.inspect}\n"
      @cache
    end

    def reset
      @cache = {}
      # print "reset: #{@method}\n"
      @db && @db.execute("DELETE FROM memo WHERE method = \"#{@method.to_s}\"")
    end
  end

  def self.included(klass)
    klass.extend(ClassMethods)
  end

  module ClassMethods
    def memo_db(filename)
      @@db = SQLite3::Database.new filename
      # @db.results_as_hash = true
      @@db.execute 'CREATE TABLE IF NOT EXISTS memo(method TEXT, last INT, args BLOB, result BLOB)'
    end

    def memo_timeout(tmout)
      @@timeout = tmout
      # print "TMOUT=#{@@timeout}\n"
    end

    def memoized
      @memoized = true
    end

    def unmemoized
      @memoized = false
    end

    def method_added(method_name)
      return unless @memoized

      @memoized = false

      unmemoized_method_name = :"unmemoized_#{method_name}"

      memoizer_name = :"memoizer_for_#{method_name}"

      memo_timeout = @@timeout || nil
      memo_db = @@db || nil

      define_method memoizer_name do
        memoizer = instance_variable_get "@#{memoizer_name}"
        if memoizer
          memoizer
        else
          instance_variable_set "@#{memoizer_name}", Memoizer.new(
            self,
            unmemoized_method_name,
            memo_timeout,
            memo_db
          )
        end
      end

      alias_method unmemoized_method_name, method_name

      define_method method_name do |*args, &block|
        # print "MEMO: '#{memoizer_name}'\n"
        send(memoizer_name).call(*args, &block)
      end

      define_method 'memo_reset' do |method|
        memoizer_name = :"memoizer_for_#{method}"
        # print "RESET: '#{memoizer_name}'\n"
        send(memoizer_name).reset
      end

      @memoized = true
    end
  end
end
