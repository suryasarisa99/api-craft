// GENERATED CODE - DO NOT MODIFY BY HAND

import 'package:re_highlight/re_highlight.dart';

final langKeyValue = Mode(
  name: "Key-Value",
  aliases: ["kv", "keyvalue", "header"],
  caseInsensitive: false,
  contains: <Mode>[
    // Optional: comment support, e.g., # comment
    Mode(className: 'comment', begin: r'#', end: r'$'),
    // Key: at the start of a line (non-space up to colon)
    Mode(
      className: 'attr', // highlight as attribute name
      begin: r'^[ \t]*[^\s:#][^:]*?(?=\s*:)',
    ),
    // Colon and space (punctuation)
    Mode(className: 'punctuation', begin: r'\s*:\s*', relevance: 0),
    // Value: anything after first colon (possibly quoted)
    Mode(
      className: 'string',
      begin: r'(:\s*)(.*)$',
      beginScope: {2: 'string'},
      relevance: 0,
    ),
  ],
);
