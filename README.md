[![Ruby](https://github.com/osyo-manga/gem-rbs-dynamic/actions/workflows/main.yml/badge.svg)](https://github.com/osyo-manga/gem-rbs-dynamic/actions/workflows/main.yml)

# RBS::Dynamic

`RBS::Dynamic` is a tool to dynamically analyze Ruby code and generate RBS

## Installation

Install the gem and add to the application's Gemfile by executing:

    $ bundle add rbs-dynamic

If bundler is not being used to manage dependencies, install the gem by executing:

    $ gem install rbs-dynamic

## Usage

Execute any Ruby script file with the `rbs-dynamic` command and generate RBS based on the executed information.

```ruby
# sample.rb
class FizzBuzz
  def initialize(value)
    @value = value
  end

  def value; @value end

  def apply
      value % 15 == 0 ? "FizzBuzz"
    : value %  3 == 0 ? "Fizz"
    : value %  5 == 0 ? "Buzz"
    : value
  end
end

p (1..20).map { FizzBuzz.new(_1).apply }
```

```shell
$ rbs-dynamic trace sample.rb
# RBS dynamic trace 0.1.0

class FizzBuzz
  private def initialize: (Integer value) -> Integer

  def apply: () -> (Integer | String)

  def value: () -> Integer

  @value: Integer
end
$
```

NOTE: In this case, no standard output is done when Ruby is executed.


#### Type supported by rbs-dynamic

* [x] class / module
    * [x] super class
    * [x] `include / prepend / extend`
    * [x] instance variables
    * [x] constant variables
    * [ ] class variables
* [x] Method
    * argument types
    * return type
    * block
    * visibility
    * class methods
* [x] literal types (e.g. `1` `:hoge`)
    * `String` literals are not supported.
* [x]  Generics types
    * [x] `Array`
    * [x] `Hash`
    * [x] `Range`
    * [ ] `Enumerable`
    * [ ] `Struct`
* [ ] Record types
* [ ] Tuple types


### commandline options

```shell
$ rbs-dynamic --help trace
Usage:
  rbs-dynamic trace [filename]

Options:
  [--root-path=ROOT-PATH]                                                  # Rooting path. Default: current dir
                                                                           # Default: /home/mayu/Dropbox/work/software/development/gem/rbs-dynamic
  [--target-filepath-pattern=TARGET-FILEPATH-PATTERN]                      # Target filepath pattern. e.g. hoge\|foo\|bar. Default '.*'
                                                                           # Default: .*
  [--ignore-filepath-pattern=IGNORE-FILEPATH-PATTERN]                      # Ignore filepath pattern. Priority over `target-filepath-pattern`. e.g. hoge\|foo\|bar. Default ''
  [--target-classname-pattern=TARGET-CLASSNAME-PATTERN]                    # Target class name pattern. e.g. RBS::Dynamic. Default '.*'
                                                                           # Default: .*
  [--ignore-classname-pattern=IGNORE-CLASSNAME-PATTERN]                    # Ignore class name pattern. Priority over `target-classname-pattern`. e.g. PP\|PrettyPrint. Default ''
  [--ignore-class-members=one two three]
                                                                           # Possible values: inclued_modules, prepended_modules, extended_modules, constant_variables, instance_variables, singleton_methods, methods
  [--method-defined-calsses=one two three]                                 # Which class defines method type. Default: defined_class and receiver_class
                                                                           # Possible values: defined_class, receiver_class
  [--show-method-location], [--no-show-method-location]                    # Show source_location and called_location in method comments. Default: no
  [--use-literal-type], [--no-use-literal-type]                            # Integer and Symbol as literal types. e.g func(:hoge, 42). Default: no
  [--with-literal-type], [--no-with-literal-type]                          # Integer and Symbol with literal types. e.g func(Symbol | :hoge | :foo). Default: no
  [--use-interface-method-argument], [--no-use-interface-method-argument]  # Define method arguments in interface. Default: no
  [--stdout], [--no-stdout]                                                # stdout at runtime. Default: no
  [--trace-c-api-method], [--no-trace-c-api-method]                        # Trace C API method. Default: no
```

#### `--method-defined-calsses`

Specify the class to be defined.

```ruby
class Base
  def func; end
end

class Sub1 < Base
end

class Sub2 < Base
end

Sub1.new.func
Sub2.new.func
```

```shell
# defined_class and receiver_class
$ rbs-dynamic trace sample.rb
# RBS dynamic trace 0.1.0

class Base
  def func: () -> NilClass
end

class Sub1 < Base
  def func: () -> NilClass
end

class Sub2 < Base
  def func: () -> NilClass
end
$
```

```shell
# only defined class
$ rbs-dynamic trace sample.rb --method-defined-calsses=defined_class
# RBS dynamic trace 0.1.0

class Base
  def func: () -> NilClass
end
```

```shell
# only receiver class
$ rbs-dynamic trace sample.rb --method-defined-calsses=receiver_class
# RBS dynamic trace 0.1.0

class Base
end

class Sub1 < Base
  def func: () -> NilClass
end

class Sub2 < Base
  def func: () -> NilClass
end
```

#### `--show-method-location`

Add method definition location and reference location to comments.

```
# sample.rb
class X
  def func1(a)
  end

  def func2
    func1(42)
  end
end

x = X.new
x.func1("homu")
x.func2
```

```shell
$ rbs-dynamic trace sample.rb --show-method-location
# RBS dynamic trace 0.1.0

class X
  # source location: sample.rb:2
  # reference location:
  #   func1(String a) -> NilClass sample.rb:11
  #   func1(Integer a) -> NilClass sample.rb:6
  def func1: (String | Integer a) -> NilClass

  # source location: sample.rb:5
  # reference location:
  #   func2() -> NilClass sample.rb:12
  def func2: () -> NilClass
end
$
```

#### `--use-literal-type`

Use Symbol literal or Integer literal as type.

```ruby
# sample.rb
class X
  def func(a)
    a.to_s
  end
end

x = X.new
x.func(1)
x.func(2)
x.func(:hoge)
x.func(:foo)
```

```shell
# Not used options
$ ./exe/rbs-dynamic trace sample.rb
# RBS dynamic trace 0.1.0

class X
  def func: (Integer | Symbol a) -> String
end
$
```

```shell
# Used options
$ rbs-dynamic trace sample.rb --use-literal-type
# RBS dynamic trace 0.1.0

class X
  def func: (1 | 2 | :hoge | :foo a) -> String
end
rbs-dynamic $
$
```

#### `--with-literal-type`

Use Symbol literal or Integer literal as type and union original type

```ruby
# sample.rb
class X
  def func(a)
    a.to_s
  end

  def func2(a)
  end
end

x = X.new
x.func(1)
x.func(2)
x.func(:hoge)
x.func(:foo)
x.func2({ id: 1, name: "homu", age: 14 })
```

```shell
$ rbs-dynamic trace sample.rb --with-literal-type
# RBS dynamic trace 0.1.0

class X
  def func: (Integer | Symbol | 1 | 2 | :hoge | :foo a) -> String

  def func2: (Hash[Symbol | :id | :name | :age, Integer | String | 1 | 14] a) -> NilClass
end
$
```


#### `--use-interface-method-argument`

Define and use interface type.

```ruby
# sample.rb
class Output
  def my_puts(a)
    puts a.to_s
  end
end

class Cat
  def to_s
    "Cat"
  end
end

class Dog
  def to_s
    "Dog"
  end
end

output = Output.new

output.my_puts Cat.new
output.my_puts Dog.new
```

```shell
$ rbs-dynamic trace sample.rb --use-interface-method-argument
# RBS dynamic trace 0.1.0

class Output
  def my_puts: (_Interface_have__to_s__1 a) -> NilClass

  interface _Interface_have__to_s__1
    def to_s: () -> String
  end
end

class Cat
  def to_s: () -> String
end

class Dog
  def to_s: () -> String
end
$
```


## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/osyo-manga/gem-rbs-dynamic.
