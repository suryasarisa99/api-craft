enum LogicalOperator { and, or }

enum FilterFieldType { num, str, bool }

enum FilterField {
  // --- General ---
  all('all', type: .bool),
  comment('comment'),
  marked('marked', type: .bool),
  marker('marker'),
  metadata('meta'),

  // --- req ---
  url('url'),
  method('method'),
  domain('domain'),
  reqHeader('req-header'),
  reqBody('req-body'),
  reqContentType('req-content-type'),
  reqWithNoRes('no-response', type: .bool),

  // --- res ---
  res('res', type: .bool),
  statusCode('status-code', type: .num),
  asset('asset', type: .bool),
  resHeader('res-header'),
  resBody('res-body'),
  resContentType('res-content-type'),

  // --- Combined ---
  header('header'),
  body('body'),
  contentType('content-type'),

  // --- Connection ---
  sourceAddress('src-addr'),
  destinationAddress('dst-addr'),
  error('error', type: .bool),

  // --- Replay ---
  replayedFlow('replay', type: .bool),
  replayedReq('replay-req', type: .bool),
  replayedRes('replay-res', type: .bool),

  // --- Protocols ---
  http('http', type: .bool),
  tcp('tcp', type: .bool),
  udp('udp', type: .bool),
  dns('dns', type: .bool),
  websocket('websocket', type: .bool),

  // --- Custom Filters on url ---
  fileExtension('ext'),
  path('path'),
  query('query'),
  queryKey('query-key'),
  queryValue('query-value'),

  // --- Script ---
  script('script', type: .str);

  const FilterField(this.prettyName, {this.type = .str});
  final String prettyName;
  final FilterFieldType type;
}

enum FilterOperator {
  // str and (may also be number)
  regex('~', FilterFieldType.str, 'Regex'),
  equals('=', FilterFieldType.str, 'Equals'),
  contains(':', FilterFieldType.str, 'Contains'),
  startsWith('^', FilterFieldType.str, 'Starts With'),
  endsWith('\$', FilterFieldType.str, 'Ends With'),
  inListStr('in', FilterFieldType.str, 'In List'),

  // num operators
  numEquals('=', FilterFieldType.num, 'Equals'),
  lessThan('<', FilterFieldType.num, 'Less Than'),
  lessThanOrEqual('<=', FilterFieldType.num, 'Less Than Or Equal'),
  greaterThan('>', FilterFieldType.num, 'Greater Than'),
  greaterThanOrEqual('>=', FilterFieldType.num, 'Greater Than Or Equal'),
  between('<>', FilterFieldType.num, 'Between'),
  inListNum('in', FilterFieldType.num, 'One Of');

  const FilterOperator(this.symbol, this.supportedType, this.label);
  final String symbol;
  final FilterFieldType supportedType;
  final String label;
}
