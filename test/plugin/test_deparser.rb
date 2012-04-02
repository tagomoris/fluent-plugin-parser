require 'helper'

class DeparserOutputTest < Test::Unit::TestCase
  def setup
    Fluent::Test.setup
  end
  
  CONFIG = %[
    remove_prefix test
    add_prefix    combined
    format        %s: %s %s %s
    format_key_names host,path,status,size
    key_name      fulltext
    reserve_data  true
  ]

  def create_driver(conf=CONFIG,tag='test')
    Fluent::Test::OutputTestDriver.new(Fluent::DeparserOutput, tag).configure(conf)
  end

  def test_configure
    assert_nothing_raised {
      d = create_driver %[
        tag april.fool
      ]
    }

    assert_raise(Fluent::ConfigError) {
      d = create_driver('')
    }
    assert_raise(Fluent::ConfigError) {
      d = create_driver %[
        tag foo.bar
      ]
    }
    assert_raise(Fluent::ConfigError) {
      d = create_driver %[
        format %s
        format_key_names x
      ]
    }
    assert_raise(Fluent::ConfigError) {
      d = create_driver %[
        tag foo.bar
        remove_prefix foo
        format %s
        format_key_names x
      ]
    }
    assert_raise(Fluent::ConfigError) {
      d = create_driver %[
        tag foo.bar
        add_prefix foo
        format %s
        format_key_names x
      ]
    }
    assert_raise(Fluent::ConfigError) {
      d = create_driver %[
        tag foo.bar
        format_key_names x
      ]
    }
    assert_raise(Fluent::ConfigError) {
      d = create_driver %[
        tag foo.bar
        format %s
      ]
    }
    assert_raise(Fluent::ConfigError) {
      d = create_driver %[
        tag foo.bar
        format %s %s %s
        format_key_names x,y
      ]
    }
    assert_nothing_raised(Fluent::ConfigError) {
      # mmm...
      d = create_driver %[
        tag foo.bar
        format %s %s
        format_key_names x,y,z
      ]
    }

    d = create_driver %[
      tag foo.bar
      format %s: %s %s
      format_key_names x,y,z
    ]
    assert_equal 'foo.bar', d.instance.tag
    assert_equal '%s: %s %s', d.instance.format
    assert_equal ['x','y','z'], d.instance.format_key_names
    assert_equal 'message', d.instance.key_name
    assert_equal false, d.instance.reserve_data
  end

  # CONFIG = %[
  #   remove_prefix test
  #   add_prefix    combined
  #   format        %s: %s %s %s
  #   format_key_names host path status size
  #   key_name      fulltext
  #   reserve_data  true
  # ]
  def test_emit
    d1 = create_driver(CONFIG, 'test.in')
    time = Time.parse("2012-01-02 13:14:15").to_i
    d1.run do
      d1.emit({'host'=>'xxx.local','path'=>'/f/1','status'=>'200','size'=>300}, time)
      d1.emit({'host'=>'yyy.local','path'=>'/f/2','status'=>'302','size'=>512}, time)
    end
    emits = d1.emits
    assert_equal 2, emits.length
    first = emits[0]
    assert_equal 'combined.in', first[0]
    assert_equal time, first[1]
    assert_equal 'xxx.local: /f/1 200 300', first[2]['fulltext']
    assert_equal ['fulltext','host','path','size','status'], first[2].keys.sort
    second = emits[1]
    assert_equal 'combined.in', second[0]
    assert_equal time, second[1]
    assert_equal 'yyy.local: /f/2 302 512', second[2]['fulltext']
    assert_equal ['fulltext','host','path','size','status'], second[2].keys.sort

    d2 = create_driver(%[
      tag combined
      format %s: %s %s
      format_key_names host,path,status
    ], 'test.in')
    time = Time.parse("2012-01-02 13:14:15").to_i
    d2.run do
      d2.emit({'host'=>'xxx.local','path'=>'/f/1','status'=>'200','size'=>300}, time)
      d2.emit({'host'=>'yyy.local','path'=>'/f/2','status'=>'302','size'=>512}, time)
    end
    emits = d2.emits
    assert_equal 2, emits.length
    first = emits[0]
    assert_equal 'combined', first[0]
    assert_equal time, first[1]
    assert_equal 'xxx.local: /f/1 200', first[2]['message']
    assert_equal ['message'], first[2].keys.sort
    second = emits[1]
    assert_equal 'combined', second[0]
    assert_equal time, second[1]
    assert_equal 'yyy.local: /f/2 302', second[2]['message']
    assert_equal ['message'], second[2].keys.sort
  end
end
