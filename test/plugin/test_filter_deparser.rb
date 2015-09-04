require 'helper'

class DeparserFilterTest < Test::Unit::TestCase
  def setup
    Fluent::Test.setup
  end

  CONFIG = %[
    format        %s: %s %s %s
    format_key_names host,path,status,size
    key_name      fulltext
    reserve_data  true
  ]

  def create_driver(conf=CONFIG,tag='test')
    Fluent::Test::FilterTestDriver.new(Fluent::DeparserFilter, tag).configure(conf)
  end

  def test_configure
    assert_raise(Fluent::ConfigError) {
      d = create_driver('')
    }

    d = create_driver %[
      format %s: %s %s
      format_key_names x,y,z
    ]
    assert_equal '%s: %s %s', d.instance.format
    assert_equal ['x','y','z'], d.instance.format_key_names
    assert_equal 'message', d.instance.key_name
    assert_equal false, d.instance.reserve_data
  end

  # CONFIG = %[
  #   format        %s: %s %s %s
  #   format_key_names host path status size
  #   key_name      fulltext
  #   reserve_data  true
  # ]
  def test_filter
    d1 = create_driver(CONFIG, 'test.no.change')
    time = Time.parse("2012-01-02 13:14:15").to_i
    d1.run do
      d1.filter({'host'=>'xxx.local','path'=>'/f/1','status'=>'200','size'=>300}, time)
      d1.filter({'host'=>'yyy.local','path'=>'/f/2','status'=>'302','size'=>512}, time)
    end
    filtered = d1.filtered_as_array
    assert_equal 2, filtered.length
    first = filtered[0]
    assert_equal 'test.no.change', first[0]
    assert_equal time, first[1]
    assert_equal 'xxx.local: /f/1 200 300', first[2]['fulltext']
    assert_equal ['fulltext','host','path','size','status'], first[2].keys.sort
    second = filtered[1]
    assert_equal 'test.no.change', second[0]
    assert_equal time, second[1]
    assert_equal 'yyy.local: /f/2 302 512', second[2]['fulltext']
    assert_equal ['fulltext','host','path','size','status'], second[2].keys.sort

    d2 = create_driver(%[
      format %s: %s %s
      format_key_names host,path,status
    ], 'test.no.change')
    time = Time.parse("2012-01-02 13:14:15").to_i
    d2.run do
      d2.filter({'host'=>'xxx.local','path'=>'/f/1','status'=>'200','size'=>300}, time)
      d2.filter({'host'=>'yyy.local','path'=>'/f/2','status'=>'302','size'=>512}, time)
    end
    filtered = d2.filtered_as_array
    assert_equal 2, filtered.length
    first = filtered[0]
    assert_equal 'test.no.change', first[0]
    assert_equal time, first[1]
    assert_equal 'xxx.local: /f/1 200', first[2]['message']
    assert_equal ['message'], first[2].keys.sort
    second = filtered[1]
    assert_equal 'test.no.change', second[0]
    assert_equal time, second[1]
    assert_equal 'yyy.local: /f/2 302', second[2]['message']
    assert_equal ['message'], second[2].keys.sort
  end
end
