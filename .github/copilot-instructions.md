# Flutter & Dart Expert Persona

# 1. Syntax & Formatting Preferences (Strict)

You MUST use static member shorthands (dot syntax) whenever the receiving type is known from the context. Do not repeat the class name.

Rules:

- Use `.start` instead of `CrossAxisAlignment.start` because for `Column` or `Row`, crossAxisAlignment is known to be of type `CrossAxisAlignment`.
- use `.new()` to call constructors when the receiving type is known from the context.

Examples:

```dart
// ❌ Bad (Old Way)
Container(
  Color: Color(0xFF00FF00),
  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
  margin: EdgeInsets.only(left: 8),
  alignment: Alignment.center,
)

// ✅ Good (New Way: Dot Shorthands)
Container(
  color: .new(0xFF00FF00),
  padding: .symmetric(horizontal: 8, vertical: 4),
  margin: .only(left: 8),
  alignment: .center,
)

// ⚠️ Common Confusions, causes Error
// so don't use dot shorthand when the receiving type is not clear from the context.

container(
  color: .red, // Error: color expects Color type, it thinks red is member of Color class, but it is a member of Colors class.

  child: Icon(.add), // Error: Icon expects IconData type, it thinks add is member of Icon class, but it is a member of Icons class.
)
```

- it supports Dot Shorthands at anywhere, function arguments, variable assignments, list elements, map values, comparison expressions, etc.

```dart
const colors = <Color>[
  .new(0xFFFF0000),
  .fromARGB(255, 0, 255, 0),
  .fromRGBO(0, 0, 255, 1.0),
];

const FontWeight weight = .bold;

// dot shorthand in expressions
void onEvent(KeyEvent event) {
  if (event is .down) {
    // handle key down
    if(event.key == .enter) {
      // handle enter key
    }
  }
}
```

## B. Null-Aware Elements in Collections

Stop using if (x != null) inside collections. Use the new null-aware element syntax ?expression.
Examples:

```dart
// ❌ Old Way
Column(
  children: [
    HeaderWidget(),
    if (optionalWidget != null) optionalWidget,
    if (isLoading) LoadingSpinner(),
  ],
)

// ✅ GOOD
Column(
  children: [
    HeaderWidget(),
    ?optionalWidget, // Only adds if not null
    if (isLoading) LoadingSpinner(),
  ],
)
```

## C. Modern Dart Features (Records & Pattern Matching)

Use Dart 3 features to reduce boilerplate.
**Switch Expressions:** Use functional switch syntax instead of switch statements for returning values.

**Records:**
Use (Type, Type) for returning multiple values instead of creating temporary classes.to access elements use : record.$1, record.$2
Use Named Records: ({double x, double y}), to access elements use : record.x, record.y

**Pattern Matching:** Destructure objects directly.

**Loops in Collections:** Use for-in loops inside collection literals. instead of chaining multiple iterators.

```dart
// ❌ OLD WAY
// to filter list based on index
list.asMap().entries.where((entry) => entry.key.isEven).toList();

// ✅ GOOD WAY
[for (var (i,item) in list.indexed() if (i.isEven) item]

// ❌ OLD WAY
// Where + Map
final results = items.where((item) => item.isActive).map((item) => item.value).toList();

// ✅ GOOD WAY
final results = [for (var item in items) if (item.isActive) item.value];
```

```dart
// ✅ GOOD
var (name, age) = getUserInfo();

String statusMessage = switch (statusCode) {
  200 => 'OK',
  404 => 'Not Found',
  _   => 'Unknown',
};
```

# 2. Deprecated APIs & Modern Replacements (Strict Enforcement)

- Stop using `color.withOpacity()`, use `Color.withValues(alpha: )` instead.
- Stop using `RawKeyEvent`,`RawKeyboardListener`, use `KeyboardEvent`, `HardwareKeyboard.instance` instead.
- Stop using `FocusNode` and `FocusScopeNode`, use `FocusController` instead
- Stop using `WillPopScope` with `onPop` callback, use `PopScope` with `onPopWithResult` callback instead.
- Stop using `MaterialStateProperty` and `MaterialState` use `WidgetStateProperty` and `WidgetState` instead.
- don't use legacy `StateNotifier` in riverpod, use `Notifier` instead.

# 3. Performance

- Prefer `const` constructors and widgets wherever possible.
- instead of `MediaQuery.of(context)` use particular property of it
  - `MediaQuery.sizeOf(context)` , `MediaQuery.paddingOf(context)`, `MediaQuery.viewInsetsOf(context)` etc.
