# Memodb

Memoize your methods in memory and save cached values into database.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'memodb'
```

And then execute:

    $ bundle install

Or install it yourself as:

    $ gem install memodb

## Usage

Example code:
   require 'memodb'
   class MyTest
     extend Memo
     memo_db('/tmp/my_cache.db')  # path to cache database
     memo_timeout(10)             # cache timeout = 10 seconds
     def initialize; @x = 0; end
     def mymethod
       @x += 1
     end
     def brute_method
       @x += 1
     end
     memoize :mymethod            # cache this method results
   end

   t = MyTest.new
   puts t.mymethod    # => 1
   puts t.mymethod    # => 1
   MyTest.memo_reset :mymethod
   puts t.mymethod    # => 2
   puts t.brute_method # => 3  # not cached

## Development

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/zhum/memodb. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [code of conduct](https://github.com/zhum/memodb/blob/master/CODE_OF_CONDUCT.md).

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the Memodb project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/zhum/memodb/blob/master/CODE_OF_CONDUCT.md).
