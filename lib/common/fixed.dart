class _FixedBuffer<T> {
  _FixedBuffer(this.capacity);

  final int capacity;
  final List<T> values = [];
  int head = 0;
  int version = 0;

  void add(T item) {
    if (values.length < capacity) {
      values.add(item);
    } else {
      values[head] = item;
      head = (head + 1) % capacity;
    }
    version++;
  }

  int physicalIndex(int index) {
    RangeError.checkValidIndex(index, values);
    return (head + index) % values.length;
  }
}

class FixedList<T> {
  final int maxLength;
  final _FixedBuffer<T> _buffer;
  final int _revision;
  List<T>? _snapshot;
  int _snapshotVersion = -1;

  FixedList(this.maxLength, {List<T>? list})
    : assert(maxLength > 0, 'FixedList without a cap grows without bound'),
      _buffer = _FixedBuffer<T>(maxLength),
      _revision = 0 {
    if (list != null) {
      for (final item in list.skip(
        list.length > maxLength ? list.length - maxLength : 0,
      )) {
        _buffer.add(item);
      }
    }
  }

  FixedList._(this.maxLength, this._buffer, this._revision);

  int get revision => _revision;

  void add(T item) => _buffer.add(item);

  void clear() {
    _buffer.values.clear();
    _buffer.head = 0;
    _buffer.version++;
  }

  FixedList<T> append(T item) {
    add(item);
    return FixedList._(maxLength, _buffer, _revision + 1);
  }

  FixedList<T> replace(Map<int, T> items) {
    items.forEach(
      (index, item) => _buffer.values[_buffer.physicalIndex(index)] = item,
    );
    _buffer.version++;
    return FixedList._(maxLength, _buffer, _revision + 1);
  }

  List<T> get list {
    if (_snapshotVersion != _buffer.version) {
      _snapshot = List.unmodifiable(
        List.generate(length, (index) => this[index]),
      );
      _snapshotVersion = _buffer.version;
    }
    return _snapshot!;
  }

  int get length => _buffer.values.length;

  T operator [](int index) => _buffer.values[_buffer.physicalIndex(index)];

  FixedList<T> copyWith() => FixedList(maxLength, list: list);

  @override
  bool operator ==(Object other) =>
      other is FixedList<T> &&
      identical(other._buffer, _buffer) &&
      other._revision == _revision;

  @override
  int get hashCode => Object.hash(identityHashCode(_buffer), _revision);
}

/// Restores the head that [latest] trimmed off [current] so a paused view
/// stays anchored; the result is capped at [limit] from the tail.
List<T> retainTrimmedHead<T>(
  List<T> current,
  List<T> latest,
  int limit, {
  Object Function(T item)? keyOf,
}) {
  if (current.isEmpty || latest.isEmpty) {
    return latest;
  }
  final first = latest.first;
  final index = keyOf == null
      ? current.indexWhere((item) => identical(item, first))
      : current.indexWhere((item) => keyOf(item) == keyOf(first));
  if (index == 0) {
    return latest;
  }
  final head = index > 0 ? current.sublist(0, index) : current;
  return List.unmodifiable([...head, ...latest].take(limit));
}
