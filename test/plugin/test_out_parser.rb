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
    assert_nothing_raised {
      d = create_driver %[
        remove_prefix foo.baz
        add_prefix foo.bar
        format json
        key_name foo
      ]
    }
    assert_nothing_raised {
      d = create_driver %[
        remove_prefix foo.baz
        add_prefix foo.bar
        format ltsv
        key_name foo
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

    d3 = create_driver(%[
      tag parsed
      key_name      data
      format        /^(?<x>[0-9])(?<y>[0-9]) (?<t>.+)$/
    ], 'test.in')
    time = Time.parse("2012-04-02 18:20:59").to_i
    d3.run do
      d3.emit({'data' => '12 20120402182059'}, time)
      d3.emit({'data' => '34 20120402182100'}, time)
      d3.emit({'data' => 'xy 20120402182101'}, time)
    end
    emits = d3.emits
    assert_equal 2, emits.length

    d3x = create_driver(%[
      tag parsed
      key_name      data
      format        /^(?<x>\d)(?<y>\d) (?<t>.+)$/
      reserve_data  yes
    ], 'test.in')
    time = Time.parse("2012-04-02 18:20:59").to_i
    d3x.run do
      d3x.emit({'data' => '12 20120402182059'}, time)
      d3x.emit({'data' => '34 20120402182100'}, time)
      d3x.emit({'data' => 'xy 20120402182101'}, time)
    end
    emits = d3x.emits
    assert_equal 3, emits.length

    d4 = create_driver(%[
      tag parsed
      key_name      data
      format        json
    ], 'test.in')
    time = Time.parse("2012-04-02 18:20:59").to_i
    d4.run do
      d4.emit({'data' => '{"xxx":"first","yyy":"second"}', 'xxx' => 'x', 'yyy' => 'y'}, time)
      d4.emit({'data' => 'foobar', 'xxx' => 'x', 'yyy' => 'y'}, time)
    end
    emits = d4.emits
    assert_equal 1, emits.length

    d4x = create_driver(%[
      tag parsed
      key_name      data
      format        json
      reserve_data  yes
    ], 'test.in')
    time = Time.parse("2012-04-02 18:20:59").to_i
    d4x.run do
      d4x.emit({'data' => '{"xxx":"first","yyy":"second"}', 'xxx' => 'x', 'yyy' => 'y'}, time)
      d4x.emit({'data' => 'foobar', 'xxx' => 'x', 'yyy' => 'y'}, time)
    end
    emits = d4x.emits
    assert_equal 2, emits.length

    first = emits[0]
    assert_equal 'parsed', first[0]
    assert_equal time, first[1]
    assert_equal '{"xxx":"first","yyy":"second"}', first[2]['data']
    assert_equal 'first', first[2]['xxx']
    assert_equal 'second', first[2]['yyy']

    second = emits[1]
    assert_equal 'parsed', second[0]
    assert_equal time, second[1]
    assert_equal 'foobar', second[2]['data']
    assert_equal 'x', second[2]['xxx']
    assert_equal 'y', second[2]['yyy']
  end

  CONFIG_LTSV =  %[
    remove_prefix foo.baz
    add_prefix foo.bar
    format ltsv
    key_name data
  ]
  def test_emit_ltsv
    d = create_driver(CONFIG_LTSV, 'foo.baz.test')
    time = Time.parse("2012-04-02 18:20:59").to_i
    d.run do
      d.emit({'data' => "xxx:first\tyyy:second", 'xxx' => 'x', 'yyy' => 'y'}, time)
      d.emit({'data' => "xxx:first\tyyy:second2", 'xxx' => 'x', 'yyy' => 'y'}, time)
    end
    emits = d.emits
    assert_equal 2, emits.length

    first = emits[0]
    assert_equal 'foo.bar.test', first[0]
    assert_equal time, first[1]
    assert_nil first[2]['data']
    assert_equal 'first', first[2]['xxx']
    assert_equal 'second', first[2]['yyy']

    second = emits[1]
    assert_equal 'foo.bar.test', second[0]
    assert_equal time, second[1]
    assert_nil first[2]['data']
    assert_equal 'first', second[2]['xxx']
    assert_equal 'second2', second[2]['yyy']

    d = create_driver(CONFIG_LTSV + %[
      reserve_data yes
    ], 'foo.baz.test')
    time = Time.parse("2012-04-02 18:20:59").to_i
    d.run do
      d.emit({'data' => "xxx:first\tyyy:second", 'xxx' => 'x', 'yyy' => 'y'}, time)
      d.emit({'data' => "xxx:first\tyyy:second2", 'xxx' => 'x', 'yyy' => 'y'}, time)
    end
    emits = d.emits
    assert_equal 2, emits.length

    first = emits[0]
    assert_equal 'foo.bar.test', first[0]
    assert_equal time, first[1]
    assert_equal "xxx:first\tyyy:second", first[2]['data']
    assert_equal 'first', first[2]['xxx']
    assert_equal 'second', first[2]['yyy']

    second = emits[1]
    assert_equal 'foo.bar.test', second[0]
    assert_equal time, second[1]
    assert_equal "xxx:first\tyyy:second", first[2]['data']
    assert_equal 'first', second[2]['xxx']
    assert_equal 'second2', second[2]['yyy']
  end

  CONFIG_TSV =  %[
    remove_prefix foo.baz
    add_prefix foo.bar
    format tsv
    key_name data
    keys key1,key2,key3
  ]
  def test_emit_ltsv
    d = create_driver(CONFIG_TSV, 'foo.baz.test')
    time = Time.parse("2012-04-02 18:20:59").to_i
    d.run do
      d.emit({'data' => "value1\tvalue2\tvalueThree", 'xxx' => 'x', 'yyy' => 'y'}, time)
    end
    emits = d.emits
    assert_equal 1, emits.length

    first = emits[0]
    assert_equal 'foo.bar.test', first[0]
    assert_equal time, first[1]
    assert_nil first[2]['data']
    assert_equal 'value1', first[2]['key1']
    assert_equal 'value2', first[2]['key2']
    assert_equal 'valueThree', first[2]['key3']
  end

  CONFIG_CSV =  %[
    remove_prefix foo.baz
    add_prefix foo.bar
    format csv
    key_name data
    keys key1,key2,key3
  ]
  def test_emit_ltsv
    d = create_driver(CONFIG_CSV, 'foo.baz.test')
    time = Time.parse("2012-04-02 18:20:59").to_i
    d.run do
      d.emit({'data' => 'value1,"value2","value""ThreeYes!"', 'xxx' => 'x', 'yyy' => 'y'}, time)
    end
    emits = d.emits
    assert_equal 1, emits.length

    first = emits[0]
    assert_equal 'foo.bar.test', first[0]
    assert_equal time, first[1]
    assert_nil first[2]['data']
    assert_equal 'value1', first[2]['key1']
    assert_equal 'value2', first[2]['key2']
    assert_equal 'value"ThreeYes!', first[2]['key3']
  end

  #TODO: apache2
  # REGEXP = /^(?<host>[^ ]*) [^ ]* (?<user>[^ ]*) \[(?<time>[^\]]*)\] "(?<method>\S+)(?: +(?<path>[^ ]*) +\S*)?" (?<code>[^ ]*) (?<size>[^ ]*)(?: "(?<referer>[^\"]*)" "(?<agent>[^\"]*)")?$/

  CONFIG_NOT_REPLACE = %[
    remove_prefix test
    key_name      data
    format        /^(?<message>.*)$/
  ]
  CONFIG_INVALID_BYTE = CONFIG_NOT_REPLACE + %[
    replace_invalid_sequence true
  ]
  def test_emit_invalid_byte
    invalid_utf8 = "\xff".force_encoding('UTF-8')

    d = create_driver(CONFIG_NOT_REPLACE, 'test.in')
    assert_raise(ArgumentError) {
      d.run do
        d.emit({'data' => invalid_utf8}, Time.now.to_i)
      end
    }

    d = create_driver(CONFIG_INVALID_BYTE, 'test.in')
    assert_nothing_raised {
      d.run do
        d.emit({'data' => invalid_utf8}, Time.now.to_i)
      end
    }
    emits = d.emits
    assert_equal 1, emits.length
    assert_nil emits[0][2]['data']
    assert_equal '?'.force_encoding('UTF-8'), emits[0][2]['message']

    d = create_driver(CONFIG_INVALID_BYTE + %[
      reserve_data yes
    ], 'test.in')
    assert_nothing_raised {
      d.run do
        d.emit({'data' => invalid_utf8}, Time.now.to_i)
      end
    }
    emits = d.emits
    assert_equal 1, emits.length
    assert_equal invalid_utf8, emits[0][2]['data']
    assert_equal '?'.force_encoding('UTF-8'), emits[0][2]['message']

    invalid_ascii = "\xff".force_encoding('US-ASCII')
    d = create_driver(CONFIG_INVALID_BYTE, 'test.in')
    assert_nothing_raised {
      d.run do
        d.emit({'data' => invalid_ascii}, Time.now.to_i)
      end
    }
    emits = d.emits
    assert_equal 1, emits.length
    assert_nil emits[0][2]['data']
    assert_equal '?'.force_encoding('US-ASCII'), emits[0][2]['message']
  end
end
