const chaiScript = """// --- Test & Expect Shim with Deep Include Support ---
function test(name, fn) {
    try {
        fn();
        _send('record_test', {description: name, status: 'passed'});
    } catch(e) {
        _send('record_test', {description: name, status: 'failed', error: e.message || e.toString()});
    }
}

// Deep equality helper
function deepEqual(a, b) {
    if (a === b) return true;
    if (a == null || b == null) return false;
    if (typeof a !== typeof b) return false;
    
    if (typeof a !== 'object') return a === b;
    
    if (Array.isArray(a) !== Array.isArray(b)) return false;
    
    if (Array.isArray(a)) {
        if (a.length !== b.length) return false;
        for (var i = 0; i < a.length; i++) {
            if (!deepEqual(a[i], b[i])) return false;
        }
        return true;
    }
    
    var keysA = Object.keys(a);
    var keysB = Object.keys(b);
    if (keysA.length !== keysB.length) return false;
    
    for (var i = 0; i < keysA.length; i++) {
        var key = keysA[i];
        if (!keysB.includes(key)) return false;
        if (!deepEqual(a[key], b[key])) return false;
    }
    
    return true;
}

// Deep subset helper - checks if needle is a subset of haystack
function isSubset(haystack, needle) {
    if (needle == null) return haystack == null;
    if (typeof needle !== 'object') return deepEqual(haystack, needle);
    
    if (Array.isArray(needle)) {
        if (!Array.isArray(haystack)) return false;
        // For arrays, check if all needle items are deeply included in haystack
        return needle.every(function(needleItem) {
            return haystack.some(function(haystackItem) {
                return deepEqual(haystackItem, needleItem);
            });
        });
    }
    
    // For objects, check if all needle properties exist in haystack with matching values
    var needleKeys = Object.keys(needle);
    for (var i = 0; i < needleKeys.length; i++) {
        var key = needleKeys[i];
        if (!(key in haystack)) return false;
        if (!isSubset(haystack[key], needle[key])) return false;
    }
    
    return true;
}

var Assertion = function(val, negate, flags) {
    this.val = val;
    this.negate = negate || false;
    this.flags = flags || {};
};

Assertion.prototype = {
    _assert: function(cond, msg) {
        if(this.negate) {
            if(cond) throw new Error(msg ? msg.replace(" to ", " NOT to ") : "Expected condition to be false");
        } else {
            if(!cond) throw new Error(msg || "Expected condition to be true");
        }
    },
    
    // Chainable getters
    get to() { return this; },
    get be() { return this; },
    get been() { return this; },
    get is() { return this; },
    get that() { return this; },
    get which() { return this; },
    get and() { return this; },
    get has() { return this; },
    get have() { return this; },
    get with() { return this; },
    get at() { return this; },
    get of() { return this; },
    get same() { return this; },
    get but() { return this; },
    get does() { return this; },
    get still() { return this; },
    get also() { return this; },
    
    // Negation
    get not() { 
        return new Assertion(this.val, !this.negate, this.flags); 
    },
    
    // Deep flag
    get deep() { 
        var newFlags = {};
        for (var k in this.flags) newFlags[k] = this.flags[k];
        newFlags.deep = true;
        return new Assertion(this.val, this.negate, newFlags);
    },
    
    // Equality assertions
    equal: function(expected) {
        if (this.flags.deep) {
            this._assert(deepEqual(this.val, expected), 
                "Expected " + JSON.stringify(this.val) + " to deep equal " + JSON.stringify(expected));
        }else if(typeof this.val === 'object' && this.val !== null){
            var v = JSON.stringify(this.val);
            var e = JSON.stringify(expected);
            this._assert(v === e, "Expected " + v + " to eql " + e);
        }
        else {
            this._assert(this.val === expected,
                "Expected " + this.val + " to equal " + expected);
          
        }
        return this;
    },
    
    equals: function(expected) {
        return this.equal(expected);
    },
    
    eq: function(expected) {
        return this.equal(expected);
    },

    eql: function(expected) {
        return this.deep.equal(expected);
    },
    
    // eql: function(expected) {
    //     var v = JSON.stringify(this.val);
    //     var e = JSON.stringify(expected);
    //     this._assert(v === e, "Expected " + v + " to eql " + e);
    //     return this;
    // },
    
    eqls: function(expected) {
        return this.eql(expected);
    },
    
    // Type assertions
    a: function(type) {
        var actualType = Array.isArray(this.val) ? 'array' : typeof this.val;
        this._assert(actualType === type, "Expected " + this.val + " to be type " + type + " but got " + actualType);
        return this;
    },
    
    an: function(type) {
        return this.a(type);
    },
    
    instanceof: function(constructor) {
        this._assert(this.val instanceof constructor, "Expected " + this.val + " to be instanceof " + constructor.name);
        return this;
    },
    
    // Truthiness
    get ok() { 
        this._assert(!!this.val, "Expected " + this.val + " to be truthy"); 
        return this;
    },
    
    get true() { 
        this._assert(this.val === true, "Expected " + this.val + " to be true"); 
        return this;
    },
    
    get false() { 
        this._assert(this.val === false, "Expected " + this.val + " to be false"); 
        return this;
    },
    
    get null() { 
        this._assert(this.val === null, "Expected " + this.val + " to be null"); 
        return this;
    },
    
    get undefined() { 
        this._assert(this.val === undefined, "Expected " + this.val + " to be undefined"); 
        return this;
    },
    
    get exist() {
        this._assert(this.val != null, "Expected " + this.val + " to exist");
        return this;
    },
    
    get empty() {
        var isEmpty = false;
        if (this.val == null) {
            isEmpty = true;
        } else if (Array.isArray(this.val) || typeof this.val === 'string') {
            isEmpty = this.val.length === 0;
        } else if (typeof this.val === 'object') {
            isEmpty = Object.keys(this.val).length === 0;
        }
        this._assert(isEmpty, "Expected " + JSON.stringify(this.val) + " to be empty");
        return this;
    },
    
    get NaN() {
        this._assert(isNaN(this.val), "Expected " + this.val + " to be NaN");
        return this;
    },
    
    // Comparison assertions
    above: function(n) {
        this._assert(this.val > n, "Expected " + this.val + " to be above " + n);
        return this;
    },
    
    gt: function(n) {
        return this.above(n);
    },
    
    greaterThan: function(n) {
        return this.above(n);
    },
    
    least: function(n) {
        this._assert(this.val >= n, "Expected " + this.val + " to be at least " + n);
        return this;
    },
    
    gte: function(n) {
        return this.least(n);
    },
    
    below: function(n) {
        this._assert(this.val < n, "Expected " + this.val + " to be below " + n);
        return this;
    },
    
    lt: function(n) {
        return this.below(n);
    },
    
    lessThan: function(n) {
        return this.below(n);
    },
    
    most: function(n) {
        this._assert(this.val <= n, "Expected " + this.val + " to be at most " + n);
        return this;
    },
    
    lte: function(n) {
        return this.most(n);
    },
    
    within: function(start, finish) {
        this._assert(this.val >= start && this.val <= finish, 
            "Expected " + this.val + " to be within " + start + ".." + finish);
        return this;
    },
    
    // String/Array/Object assertions with deep support
    include: function(k) {
        var included = false;
        
        if (this.flags.deep) {
            // Deep include for objects and arrays
            if (typeof this.val === 'object' && this.val !== null) {
                if (Array.isArray(this.val)) {
                    // For arrays, check if any element deeply equals k
                    included = this.val.some(function(item) {
                        return deepEqual(item, k);
                    });
                } else if (typeof k === 'object' && k !== null) {
                    // For objects, check if k is a subset of this.val
                    included = isSubset(this.val, k);
                } else {
                    // Check if value exists in object
                    var values = Object.keys(this.val).map(function(key) {
                        return this.val[key];
                    }.bind(this));
                    included = values.some(function(v) {
                        return deepEqual(v, k);
                    });
                }
            } else if (typeof this.val === 'string') {
                included = this.val.indexOf(k) !== -1;
            }
        } else {
            // Shallow include
            if (typeof this.val === 'string' || Array.isArray(this.val)) {
                included = this.val.indexOf(k) !== -1;
            } else if (typeof this.val === 'object' && this.val !== null) {
                included = k in this.val;
            }
        }
        
        this._assert(included, 
            "Expected " + JSON.stringify(this.val) + 
            (this.flags.deep ? " to deep include " : " to include ") + 
            JSON.stringify(k));
        return this;
    },
    
    includes: function(k) {
        return this.include(k);
    },
    
    contain: function(k) {
        return this.include(k);
    },
    
    contains: function(k) {
        return this.include(k);
    },
    
    length: function(len) {
        var vLen = this.val ? this.val.length : undefined;
        this._assert(vLen === len, "Expected length " + len + " but got " + vLen);
        return this;
    },
    
    lengthOf: function(len) {
        return this.length(len);
    },
    
    property: function(prop, val) {
        var has = this.val && (prop in this.val);
        if (arguments.length > 1) {
            var match = has && (this.flags.deep ? deepEqual(this.val[prop], val) : this.val[prop] == val);
            this._assert(match, "Expected property " + prop + " to be " + JSON.stringify(val));
        } else {
            this._assert(has, "Expected to have property " + prop);
        }
        return this;
    },
    
    ownProperty: function(prop) {
        var has = this.val && this.val.hasOwnProperty(prop);
        this._assert(has, "Expected to have own property " + prop);
        return this;
    },
    
    haveOwnProperty: function(prop) {
        return this.ownProperty(prop);
    },
    
    keys: function() {
        var expectedKeys = Array.prototype.slice.call(arguments);
        var actualKeys = this.val ? Object.keys(this.val) : [];
        var match = expectedKeys.length === actualKeys.length && 
                   expectedKeys.every(function(k) { return actualKeys.indexOf(k) !== -1; });
        this._assert(match, "Expected keys " + JSON.stringify(actualKeys) + " to match " + JSON.stringify(expectedKeys));
        return this;
    },
    
    key: function(k) {
        return this.keys(k);
    },
    
    // Special assertions
    oneOf: function(list) {
        var found = list.indexOf(this.val) !== -1;
        this._assert(found, "Expected " + this.val + " to be one of " + JSON.stringify(list));
        return this;
    },
    
    match: function(regex) {
        var matches = regex.test(this.val);
        this._assert(matches, "Expected " + this.val + " to match " + regex);
        return this;
    },
    
    matches: function(regex) {
        return this.match(regex);
    },
    
    string: function(str) {
        var contains = typeof this.val === 'string' && this.val.indexOf(str) !== -1;
        this._assert(contains, "Expected " + this.val + " to contain string " + str);
        return this;
    },
    
    members: function(subset) {
        if (!Array.isArray(this.val)) {
            throw new Error("Expected array but got " + typeof this.val);
        }
        var hasAll = subset.every(function(item) {
            if (this.flags.deep) {
                return this.val.some(function(v) { return deepEqual(v, item); });
            } else {
                return this.val.indexOf(item) !== -1;
            }
        }.bind(this));
        this._assert(hasAll, "Expected " + JSON.stringify(this.val) + " to have members " + JSON.stringify(subset));
        return this;
    },
    
    throw: function(errorType, message) {
        if (typeof this.val !== 'function') {
            throw new Error("Expected a function to test throw");
        }
        var threw = false;
        var caughtError = null;
        try {
            this.val();
        } catch(e) {
            threw = true;
            caughtError = e;
            if (errorType && !(e instanceof errorType)) {
                throw new Error("Expected error of type " + errorType.name);
            }
            if (message && e.message.indexOf(message) === -1) {
                throw new Error("Expected error message to contain '" + message + "' but got '" + e.message + "'");
            }
        }
        this._assert(threw, "Expected function to throw");
        return this;
    },
    
    throws: function(errorType, message) {
        return this.throw(errorType, message);
    },
    
    status: function(s) {
        this._assert(this.val == s, "Expected status " + s + " but got " + this.val);
        return this;
    },
    
    closeTo: function(expected, delta) {
        var diff = Math.abs(this.val - expected);
        this._assert(diff <= delta, "Expected " + this.val + " to be close to " + expected + " +/- " + delta);
        return this;
    },
    
    approximately: function(expected, delta) {
        return this.closeTo(expected, delta);
    },
    
    respondTo: function(method) {
        var responds = this.val && typeof this.val[method] === 'function';
        this._assert(responds, "Expected " + this.val + " to respond to " + method);
        return this;
    },
    
    satisfy: function(fn) {
        var satisfied = fn(this.val);
        this._assert(satisfied, "Expected " + this.val + " to satisfy function");
        return this;
    },
    
    satisfies: function(fn) {
        return this.satisfy(fn);
    },
};

function expect(val) {
    return new Assertion(val);
}

function describe(name, fn) {
    try {
        _send('describe_start', {description: name});
        fn();
        _send('describe_end', {description: name});
    } catch(e) {
        _send('describe_error', {description: name, error: e.message || e.toString()});
    }
}
""";
