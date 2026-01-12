final String bridge = """
function _send(channel, args) {
    var payload = JSON.stringify(args || {});
    if (typeof sendMessage !== 'undefined') {
      return sendMessage(channel, payload);
    } else if (typeof SendMessage !== 'undefined') {
      return SendMessage(channel, payload);
    }
    return null;
}

var console = { 
    log: function(...args) { _send('log', {args:args}); },
    debug: function(...args) { _send('debug', {args:args}); },
    error: function(...args) { _send('error', {args:args}); },
    warn: function(...args) { _send('warn', {args:args}); },
    info: function(...args) { _send('info', {args:args}); }
};
var log = function(...args) { _send('log', {args:args}); };
var prompt = async function(msg) { return _send('prompt', {msg: msg}); };

function getReq(idOrPath) {
    var contextId = (typeof req !== 'undefined' && req && req.id) ? req.id : null;
    var resolved = _send('resolveId', {id: idOrPath, contextId: contextId});
    var finalId = resolved || idOrPath;

    return {
      id: finalId,
      getName: function() { return _send('getReqName', {id: this.id}); },
      getUrl: function() { return _send('getReqUrl', {id: this.id}); },
      getMethod: function() { return _send('getReqMethod', {id: this.id}); },
      getResolved: async function() { 
          var res = await _send('getResolvedReq', {id: this.id});
          try { return JSON.parse(res); } catch(e) { return null; }
      },
      getBody: async function() { 
          var res = await _send('getReqBody', {id: this.id});
          try { return JSON.parse(res); } catch(e) { return res; }
      },
      setUrl: function(u) { _send('setReqUrl', {id: this.id, url: u}); },
      setMethod: function(m) { _send('setReqMethod', {id: this.id, method: m}); },
      setBody: function(b) { _send('setReqBody', {id: this.id, body: b}); },
      getHeaders: function() { 
          var res = _send('getReqHeaders', {id: this.id});
          try { return JSON.parse(res); } catch(e) { return []; }
      },
      getHeadersMap: function() {
          var res = _send('getReqHeadersMap', {id: this.id});
          try { return JSON.parse(res); } catch(e) { return {}; }
      },
      getHeader: function(k) { return _send('getReqHeader', {id: this.id, key: k}); },
      setHeaders: function(h) { _send('setReqHeaders', {id: this.id, headers: h}); },
      setHeader: function(k, v) { _send('setReqHeader', {id: this.id, key: k, value: v}); },
      addHeader: function(k, v) { _send('addReqHeader', {id: this.id, key: k, value: v}); },
      addHeaders: function(h) { _send('addReqHeaders', {id: this.id, headers: h}); }
    };
}
async function getRes(idOrPath, { purpose, behavior, ttl } = {}) {
  const res = await _send('getResponse', { id: idOrPath, purpose, behavior, ttl });
  try { return JSON.parse(res); } catch { return null; }
}

var api = {
    setVar: function(k, v) { _send('setVar', {key:k, value:v}); },
    getVar: function(k) { return _send('getVar', {key:k}); },
    getReq: function(id) { return getReq(id); },
    runRequest: async function(path) {
        var res = await _send('runRequest', {path: path, contextId: req.id});
        try { return JSON.parse(res); } catch(e) { 
        console.log(e);
        return null; }
    },
    sendRequest: async function(opts, callback) {
        try {
            var res = await _send('sendRequest', opts);
            var parsed = JSON.parse(res);
            if (callback) callback(null, parsed);
            return parsed;
        } catch(e) {
            if (callback) callback(e, null);
            throw e;
        }
    },
    setNextRequest: function(next) { _send('setNextRequest', {next: next}); },
    runner: {
        setNextRequest: function(next) { _send('setNextRequest', {next: next}); }
    }
};

var toast = {
    success: function(m, o) { _send('toast', {type:'success', msg:m, description: o?.description, duration: o?.duration}); },
    error: function(m, o) { _send('toast', {type:'error', msg:m, description: o?.description, duration: o?.duration}); },
    info: function(m, o) { _send('toast', {type:'info', msg:m, description: o?.description, duration: o?.duration}); },
    warn: function(m, o) { _send('toast', {type:'warning', msg:m, description: o?.description, duration: o?.duration}); },
};

var jar = {
    get: function(k) { 
        var res = _send('getCookie', {key:k});
        try { return res ? JSON.parse(res) : null; } catch(e) { return null; }
    },
    add: function(c) { _send('addCookie', c); },
    update: function(c) { _send('updateCookie', c); },
    remove: function(k) { _send('removeCookie', {key:k}); }
};
""";
