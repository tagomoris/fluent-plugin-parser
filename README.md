# fluent-plugin-parser

**NOTE: This plugin is outdated for Fluentd v0.14 (Fluentd v0.14 has 'parser' filter plugin)**

## Component

### ParserOutput

This is a [Fluentd](http://fluentd.org) plugin to parse strings in log messages
and re-emit them.

### ParserFilter

Filter version of ParserOutput. In fluentd v0.12 or later, ParserFilter is recommended for simple configuartion and better performance.

### DeparserOutput

Generate string log value from log message, with specified format and fields, and re-emit.

### DeparserFilter

Filter version of DeparserOutput. In fluentd v0.12 or later, DeparserFilter is recommended for simple configuartion and better performance.

## Configuration

### ParserOutput

ParserOutput has just same with 'in_tail' about 'format' and 'time\_format':

    <match raw.apache.common.*>
      @type parser
      remove_prefix raw
      format /^(?<host>[^ ]*) [^ ]* (?<user>[^ ]*) \[(?<time>[^\]]*)\] "(?<method>\S+)(?: +(?<path>[^ ]*) +\S*)?" (?<code>[^ ]*) (?<size>[^ ]*)$/
      time_format %d/%b/%Y:%H:%M:%S %z
      key_name message
    </match>

Of course, you can use predefined format 'apache' and 'syslog':

    <match raw.apache.combined.*>
      @type parser
      remove_prefix raw
      format apache
      key_name message
    </match>

`fluent-plugin-parser` uses parser plugins of Fluentd (and your own customized parser plugin).
See document page for more details: http://docs.fluentd.org/articles/parser-plugin-overview

If you want original attribute-data pair in re-emitted message, specify 'reserve_data':

    <match raw.apache.*>
      @type parser
      tag apache
      format apache
      key_name message
      reserve_data yes
    </match>

If you want to suppress 'pattern not match' log, specify 'suppress\_parse\_error\_log true' to configuration.
default value is false.

    <match in.hogelog>
      @type parser
      tag hogelog
      format /^col1=(?<col1>.+) col2=(?<col2>.+)$/
      key_name message
      suppress_parse_error_log true
    </match>

To store parsed values with specified key name prefix, use `inject_key_prefix` option:

    <match raw.sales.*>
      @type parser
      tag sales
      format json
      key_name sales
      reserve_data      yes
      inject_key_prefix sales.
    </match>
    # input string of 'sales': {"user":1,"num":2}
    # output data: {"sales":"{\"user\":1,\"num\":2}","sales.user":1, "sales.num":2}

To store parsed values as a hash value in a field, use `hash_value_field` option:

    <match raw.sales.*>
      @type parser
      tag sales
      format json
      key_name sales
      hash_value_field parsed
    </match>
    # input string of 'sales': {"user":1,"num":2}
    # output data: {"parsed":{"user":1, "num":2}}

Other options (ex: `reserve_data`, `inject_key_prefix`) are available with `hash_value_field`.

    # output data: {"sales":"{\"user\":1,\"num\":2}", "parsed":{"sales.user":1, "sales.num":2}}

Not to parse times (reserve that field like 'time' in record), specify `time_parse no`:

    <match raw.sales.*>
      type parser
      tag sales
      format json
      key_name sales
      hash_value_field parsed
      time_parse no
    </match>
    # input string of 'sales': {"user":1,"num":2,"time":"2013-10-31 12:48:33"}
    # output data: {"parsed":{"user":1, "num":2,"time":"2013-10-31 12:48:33"}}

### DeparserOutput

To build CSV from field 'store','item','num', as field 'csv', without raw data:

    <match in.marketlog.**>
      @type deparser
      remove_prefix in
      format %s,%s,%s
      format_key_names store,item,num
      key_name csv
    </match>

To build same CSV, as additional field 'csv', with reserved raw fields:

    <match in.marketlog>
      @type deparser
      tag marketlog
      format %s,%s,%s
      format_key_names store,item,num
      key_name csv
      reserve_data yes
    </match>

### ParserFilter

This is the filter version of ParserOutput.

Note that this filter version of parser plugin does not have modifing tag functionality.

ParserFilter has just same with 'in_tail' about 'format' and 'time\_format':

    <filter raw.apache.common.*>
      @type parser
      format /^(?<host>[^ ]*) [^ ]* (?<user>[^ ]*) \[(?<time>[^\]]*)\] "(?<method>\S+)(?: +(?<path>[^ ]*) +\S*)?" (?<code>[^ ]*) (?<size>[^ ]*)$/
      time_format %d/%b/%Y:%H:%M:%S %z
      key_name message
    </filter>

Of course, you can use predefined format 'apache' and 'syslog':

    <filter raw.apache.combined.*>
      @type parser
      format apache
      key_name message
    </filter>

`fluent-plugin-parser` uses parser plugins of Fluentd (and your own customized parser plugin).
See document page for more details: http://docs.fluentd.org/articles/parser-plugin-overview

If you want original attribute-data pair in re-emitted message, specify 'reserve_data':

    <filter raw.apache.*>
      @type parser
      format apache
      key_name message
      reserve_data yes
    </filter>

If you want to suppress 'pattern not match' log, specify 'suppress\_parse\_error\_log true' to configuration.
default value is false.

    <filter in.hogelog>
      @type parser
      format /^col1=(?<col1>.+) col2=(?<col2>.+)$/
      key_name message
      suppress_parse_error_log true
    </filter>

To store parsed values with specified key name prefix, use `inject_key_prefix` option:

    <filter raw.sales.*>
      @type parser
      format json
      key_name sales
      reserve_data      yes
      inject_key_prefix sales.
    </filter>
    # input string of 'sales': {"user":1,"num":2}
    # output data: {"sales":"{\"user\":1,\"num\":2}","sales.user":1, "sales.num":2}

To store parsed values as a hash value in a field, use `hash_value_field` option:

    <filter raw.sales.*>
      @type parser
      tag sales
      format json
      key_name sales
      hash_value_field parsed
    </filter>
    # input string of 'sales': {"user":1,"num":2}
    # output data: {"parsed":{"user":1, "num":2}}

Other options (ex: `reserve_data`, `inject_key_prefix`) are available with `hash_value_field`.

    # output data: {"sales":"{\"user\":1,\"num\":2}", "parsed":{"sales.user":1, "sales.num":2}}

Not to parse times (reserve that field like 'time' in record), specify `time_parse no`:

    <filter raw.sales.*>
      @type parser
      format json
      key_name sales
      hash_value_field parsed
      time_parse no
    </filter>
    # input string of 'sales': {"user":1,"num":2,"time":"2013-10-31 12:48:33"}
    # output data: {"parsed":{"user":1, "num":2,"time":"2013-10-31 12:48:33"}}

### DeparserFilter

Note that this filter version of deparser plugin does not have modifing tag functionality.

To build CSV from field 'store','item','num', as field 'csv', without raw data:

    <filter in.marketlog.**>
      @type deparser
      format %s,%s,%s
      format_key_names store,item,num
      key_name csv
    </filter>

To build same CSV, as additional field 'csv', with reserved raw fields:

    <filter in.marketlog>
      @type deparser
      format %s,%s,%s
      format_key_names store,item,num
      key_name csv
      reserve_data yes
    </filter>

## TODO

* consider what to do next
* patches welcome!

## Copyright

* Copyright
  * Copyright (c) 2012- TAGOMORI Satoshi (tagomoris)
* License
  * Apache License, Version 2.0
