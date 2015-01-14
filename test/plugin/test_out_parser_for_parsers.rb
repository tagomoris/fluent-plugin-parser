require 'helper'
require_relative '../custom_parser'

class ParserOutputParsersTest < Test::Unit::TestCase
  def setup
    Fluent::Test.setup
  end

  def create_driver(conf, tag)
    Fluent::Test::OutputTestDriver.new(Fluent::ParserOutput, tag).configure(conf)
  end

  def test_regexp_parser
    # exists in test_out_parser
  end

  def test_json_parser
    # exists in test_out_parser
  end

  def test_tsv_parser
    # exists in test_out_parser
  end

  def test_ltsv_parser
    # exists in test_out_parser
  end

  def test_csv_parser
    # exists in test_out_parser
  end

  def test_none_parser
    d = create_driver(<<EOF, 'test.in')
remove_prefix test
add_prefix    parsed
key_name      message
format        none
EOF
    time = Time.parse("2014-11-05 15:59:30").to_i
    d.run do
      d.emit({"message" => "aaaa bbbb cccc 1"}, time)
      d.emit({"message" => "aaaa bbbb cccc 2"}, time)
      d.emit({"message" => "aaaa bbbb cccc 3"}, time)
      d.emit({"message" => "aaaa bbbb cccc 4"}, time)
    end

    e = d.emits
    assert_equal 4, e.length

    assert_equal 'parsed.in', e[0][0]
    assert_equal time, e[0][1]
    assert_equal 'aaaa bbbb cccc 1', e[0][2]['message']

    assert_equal 'parsed.in', e[1][0]
    assert_equal time, e[1][1]
    assert_equal 'aaaa bbbb cccc 2', e[1][2]['message']

    assert_equal 'parsed.in', e[2][0]
    assert_equal time, e[2][1]
    assert_equal 'aaaa bbbb cccc 3', e[2][2]['message']

    assert_equal 'parsed.in', e[3][0]
    assert_equal time, e[3][1]
    assert_equal 'aaaa bbbb cccc 4', e[3][2]['message']
  end

  def test_apache_parser
    log1 = '127.0.0.1 - frank [10/Oct/2000:13:55:36 -0700] "GET /apache_pb.gif HTTP/1.0" 200 2326'
    log2 = '127.0.0.1 - frank [10/Oct/2000:13:55:36 -0700] "GET /apache_pb.gif HTTP/1.0" 200 2326 "http://www.example.com/start.html" "Mozilla/4.08 [en] (Win98; I ;Nav)"'
    log_time = Time.parse("2000-10-10 13:55:36 -0700").to_i

    d = create_driver(<<EOF, 'test.in')
remove_prefix test
add_prefix    parsed
key_name      message
format        apache
EOF
    time = Time.parse("2014-11-05 15:59:30").to_i
    d.run do
      d.emit({"message" => log1}, time)
      d.emit({"message" => log2}, time)
    end

    e = d.emits
    assert_equal 2, e.length

    assert_equal 'parsed.in', e[0][0]
    assert_equal log_time, e[0][1]
    assert_equal '127.0.0.1', e[0][2]['host']
    assert_equal 'frank', e[0][2]['user']
    assert_equal 'GET', e[0][2]['method']
    assert_equal '/apache_pb.gif', e[0][2]['path']
    assert_equal '200', e[0][2]['code']
    assert_equal '2326', e[0][2]['size']
    assert_nil e[0][2]['referer']
    assert_nil e[0][2]['agent']

    assert_equal 'parsed.in', e[1][0]
    assert_equal log_time, e[1][1]
    assert_equal '127.0.0.1', e[1][2]['host']
    assert_equal 'frank', e[1][2]['user']
    assert_equal 'GET', e[1][2]['method']
    assert_equal '/apache_pb.gif', e[1][2]['path']
    assert_equal '200', e[1][2]['code']
    assert_equal '2326', e[1][2]['size']
    assert_equal 'http://www.example.com/start.html', e[1][2]['referer']
    assert_equal 'Mozilla/4.08 [en] (Win98; I ;Nav)', e[1][2]['agent']
  end

  def test_apache_parser_with_types
    log = '127.0.0.1 - frank [10/Oct/2000:13:55:36 -0700] "GET /apache_pb.gif HTTP/1.0" 200 2326 "http://www.example.com/start.html" "Mozilla/4.08 [en] (Win98; I ;Nav)"'
    log_time = Time.parse("2000-10-10 13:55:36 -0700").to_i

    d = create_driver(<<EOF, 'test.in')
remove_prefix test
add_prefix    parsed
key_name      message
format        apache
types code:integer,size:integer
EOF
    time = Time.parse("2014-11-05 15:59:30").to_i
    d.run do
      d.emit({"message" => log}, time)
    end

    e = d.emits
    assert_equal 1, e.length

    assert_equal 'parsed.in', e[0][0]
    assert_equal log_time, e[0][1]
    assert_equal '127.0.0.1', e[0][2]['host']
    assert_equal 'frank', e[0][2]['user']
    assert_equal 'GET', e[0][2]['method']
    assert_equal '/apache_pb.gif', e[0][2]['path']
    assert_equal 200, e[0][2]['code']
    assert_equal 2326, e[0][2]['size']
    assert_equal 'http://www.example.com/start.html', e[0][2]['referer']
    assert_equal 'Mozilla/4.08 [en] (Win98; I ;Nav)', e[0][2]['agent']
  end

  def test_syslog_parser
    loglines = <<LOGS
Nov  5 16:19:48 myhost.local netbiosd[50]: name servers down?
Nov  5 16:21:20 myhost.local coreaudiod[320]: Disabled automatic stack shots because audio IO is active
Nov  5 16:21:20 myhost.local coreaudiod[320]: Enabled automatic stack shots because audio IO is inactive
LOGS
    logs = loglines.split("\n").reject(&:empty?)

    d = create_driver(<<EOF, 'test.in')
remove_prefix test
add_prefix    parsed
key_name      message
format        syslog
EOF
    time = Time.parse("11/05 15:59:30").to_i # time is assumed as current year
    d.run do
      d.emit({"message" => logs[0]}, time)
      d.emit({"message" => logs[1]}, time)
      d.emit({"message" => logs[2]}, time)
    end

    emits = d.emits
    assert_equal 3, emits.length

    e = emits[0]
    assert_equal 'parsed.in', e[0]
    assert_equal Time.parse("11/05 16:19:48").to_i, e[1]
    r = e[2]
    assert_equal 'myhost.local', r['host']
    assert_equal 'netbiosd', r['ident']
    assert_equal '50', r['pid']
    assert_equal 'name servers down?', r['message']

    e = emits[1]
    assert_equal 'parsed.in', e[0]
    assert_equal Time.parse("11/05 16:21:20").to_i, e[1]
    r = e[2]
    assert_equal 'myhost.local', r['host']
    assert_equal 'coreaudiod', r['ident']
    assert_equal '320', r['pid']
    assert_equal 'Disabled automatic stack shots because audio IO is active', r['message']

    e = emits[2]
    assert_equal 'parsed.in', e[0]
    assert_equal Time.parse("11/05 16:21:20").to_i, e[1]
    r = e[2]
    assert_equal 'myhost.local', r['host']
    assert_equal 'coreaudiod', r['ident']
    assert_equal '320', r['pid']
    assert_equal 'Enabled automatic stack shots because audio IO is inactive', r['message']
  end

  def x_test_multiline_parser
    # I can't configure this format well...
    log1 = <<LOG
*** 2014/11/05 16:33:01 -0700
  host: myhost
  port: 2048
  message: first line
LOG
    log2 = <<LOG
*** 2014/11/05 16:33:02 +0900
  host: myhost
  port: 2049
  message: second line
LOG
    log3 = <<LOG
*** 2014/11/05 16:43:11 +1100
LOG
    d = create_driver(<<'EOF', 'test.in')
remove_prefix test
add_prefix    parsed
key_name      message
format        multiline
time_format %Y/%m/%d %H:%M:%S %z
format_firstline /^\*\*\* /
format1 /\*\*\* (?<time>\d{4}/\d\d/\d\d/ \d\d:\d\d:\d\d [-+]\d{4})/
format2 /\s*host: (?<host>[^\s]+)/
format3 /\s*port: (?<port>\d+)/
format4 /\s*message: (?<message>[^ ]*)/
EOF
    time = Time.parse("2014-11-05 15:59:30").to_i
    d.run do
      d.emit({"message" => log1}, time)
      d.emit({"message" => log2}, time)
      d.emit({"message" => log3}, time)
    end

    emits = d.emits
    assert_equal 2, emits.length

    e = emits[0]
    assert_equal 'parsed.in', e[0]
    assert_equal Time.parse("2014-11-05 16:33:01 -0700").to_i, e[1]
    r = e[2]
    assert_equal 'myhost', r['host']
    assert_equal '2048', r['port']
    assert_equal 'first line', r['message']

    e = emits[1]
    assert_equal 'parsed.in', e[0]
    assert_equal Time.parse("2014-11-05 16:33:02 +0900").to_i, e[1]
    r = e[2]
    assert_equal 'myhost', r['host']
    assert_equal '2049', r['port']
    assert_equal 'second line', r['message']
  end

  def test_custom_parser
    d = create_driver(<<'EOF', 'test.in')
remove_prefix test
add_prefix    parsed
key_name      message
format        kv_pair
time_format %Y-%m-%d %H:%M:%S %z
delim1 :
delim2 ,
EOF
    time = Time.parse("2014-11-05 15:59:30").to_i
    d.run do
      d.emit({"message" => "k1:v1,k2:v2,k3:1,time:2014-11-05 00:00:00 +0000"}, time)
      d.emit({"message" => "k1:v1,k2:v2,k3:2"}, time) # original time is used
      d.emit({"message" => "k1:v1,k2:v2,k3:3,time:2014-11-05 00:00:00"}, time) # time parse error -> not emitted
    end
    emits = d.emits
    assert_equal 2, emits.length

    e = emits[0]
    assert_equal 'parsed.in', e[0]
    assert_equal Time.parse("2014-11-05 00:00:00 +0000").to_i, e[1]
    r = e[2]
    assert_equal 'v1', r['k1']
    assert_equal 'v2', r['k2']
    assert_equal '1', r['k3']

    e = emits[1]
    assert_equal 'parsed.in', e[0]
    assert_equal Time.parse("2014-11-05 15:59:30").to_i, e[1]
    r = e[2]
    assert_equal 'v1', r['k1']
    assert_equal 'v2', r['k2']
    assert_equal '2', r['k3']
  end
end
