# fluent-plugin-parser

## Component

### ParserOutput

Parse string in log message, and re-emit.

### DeparserOutput

Generate string log value from log message, with specified format and fields, and re-emit.

## Configuration

### ParserOutput

ParserOutput has just same with 'in_tail' about 'format' and 'time\_format':

    <match raw.apache.common.*>
      type parser
      remove_prefix raw
      format /^(?<host>[^ ]*) [^ ]* (?<user>[^ ]*) \[(?<time>[^\]]*)\] "(?<method>\S+)(?: +(?<path>[^ ]*) +\S*)?" (?<code>[^ ]*) (?<size>[^ ]*)$/
      time_format %d/%b/%Y:%H:%M:%S %z
      key_name message
    </match>

Of course, you can use predefined format 'apache' and 'syslog':

    <match raw.apache.combined.*>
      type parser
      remove_prefix raw
      format apache
      key_name message
    </match>

If you want original attribute-data pair in re-emitted message, specify 'reserve_data':

    <match raw.apache.*>
      type parser
      tag apache
      format apache
      key_name message
      reserve_data yes
    </match>

Format 'json' is also supported:

    <match raw.sales.*>
      type parser
      tag sales
      format json
      key_name sales
    </match>

Format 'ltsv'(Labeled-TSV (Tab separated values)) is also supported:

    <match raw.sales.*>
      type parser
      tag sales
      format ltsv
      key_name sales
    </match>

'LTSV' is format like below, unlinke json, easy to write with simple formatter (ex: LogFormat of apache):

    KEY1:VALUE1 [TAB] KEY2:VALUE2 [TAB] ...

### DeparserOutput

To build CSV from field 'store','item','num', as field 'csv', without raw data:

    <match in.marketlog.**>
      type deparser
      remove_prefix in
      format %s,%s,%s
      format_key_names store,item,num
      key_name csv
    </match>

To build same CSV, as additional field 'csv', with reserved raw fields:

    <match in.marketlog>
      type deparser
      tag marketlog
      format %s,%s,%s
      format_key_names store,item,num
      key_name csv
      reserve_data yes
    </match>

## TODO

* consider what to do next
* patches welcome!

## Copyright

Copyright:: Copyright (c) 2012- TAGOMORI Satoshi (tagomoris)
License::   Apache License, Version 2.0
