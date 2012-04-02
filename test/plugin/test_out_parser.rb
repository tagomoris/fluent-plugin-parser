require 'helper'

class ParserOutputTest < Test::Unit::TestCase
  def setup
    Fluent::Test.setup
  end
  
  CONFIG = %[
    remove_prefix test
    add_prefix    parsed
    key_name      message
    format        /^(?<x>.)(?<y>.) (?<time>.+)$/
    time_format   %Y%m%d%H%M%S
    reserve_data  true
  ]

  def create_driver(conf=CONFIG,tag='test')
    Fluent::Test::OutputTestDriver.new(Fluent::ParserOutput, tag).configure(conf)
  end

  def test_configure
    assert_raise(Fluent::ConfigError) {
      d = create_driver('')
    }
    assert_nothing_raised {
      d = create_driver %[
        tag foo.bar
        format /(?<x>.)/
        key_name foo
      ]
    }
    assert_nothing_raised {
      d = create_driver %[
        remove_prefix foo.bar
        format /(?<x>.)/
        key_name foo
      ]
    }
    assert_nothing_raised {
      d = create_driver %[
        add_prefix foo.bar
        format /(?<x>.)/
        key_name foo
      ]
    }
    assert_nothing_raised {
      d = create_driver %[
        remove_prefix foo.baz
        add_prefix foo.bar
        format /(?<x>.)/
        key_name foo
      ]
    }
    assert_raise(Fluent::ConfigError) {
      d = create_driver %[
        remove_prefix foo.baz
        add_prefix foo.bar
        format /(?<x>.)/
        key_name foo
        time_format %Y%m%d
      ]
    }

    d = create_driver %[
      tag foo.bar
      key_name foo
      format /(?<x>.)/
    ]
    assert_equal false, d.instance.reserve_data
  end

  # CONFIG = %[
  #   remove_prefix test
  #   add_prefix    parsed
  #   key_name      message
  #   format        /^(?<x>.)(?<y>.) (?<time>.+)$/
  #   time_format   %Y%m%d%H%M%S
  #   reserve_data  true
  # ]
  def test_emit
    d1 = create_driver(CONFIG, 'test.in')
    time = Time.parse("2012-01-02 13:14:15").to_i
    d1.run do
      d1.emit({'message' => '12 20120402182059'}, time)
      d1.emit({'message' => '34 20120402182100'}, time)
    end
    emits = d1.emits
    assert_equal 2, emits.length

    first = emits[0]
    assert_equal 'parsed.in', first[0]
    assert_equal Time.parse("2012-04-02 18:20:59").to_i, first[1]
    assert_equal '1', first[2]['x']
    assert_equal '2', first[2]['y']
    assert_equal '12 20120402182059', first[2]['message']

    second = emits[1]
    assert_equal 'parsed.in', second[0]
    assert_equal Time.parse("2012-04-02 18:21:00").to_i, second[1]
    assert_equal '3', second[2]['x']
    assert_equal '4', second[2]['y']

    d2 = create_driver(%[
      tag parsed
      key_name      data
      format        /^(?<x>.)(?<y>.) (?<t>.+)$/
    ], 'test.in')
    time = Time.parse("2012-04-02 18:20:59").to_i
    d2.run do
      d2.emit({'data' => '12 20120402182059'}, time)
      d2.emit({'data' => '34 20120402182100'}, time)
    end
    emits = d2.emits
    assert_equal 2, emits.length

    first = emits[0]
    assert_equal 'parsed', first[0]
    assert_equal time, first[1]
    assert_nil first[2]['data']
    assert_equal '1', first[2]['x']
    assert_equal '2', first[2]['y']
    assert_equal '20120402182059', first[2]['t']

    second = emits[1]
    assert_equal 'parsed', second[0]
    assert_equal time, second[1]
    assert_nil second[2]['data']
    assert_equal '3', second[2]['x']
    assert_equal '4', second[2]['y']
    assert_equal '20120402182100', second[2]['t']
  end
end
