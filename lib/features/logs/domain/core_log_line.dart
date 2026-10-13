/// Severity of a core log line, as sing-box numbers them.
enum LogLevel { panic, fatal, error, warn, info, debug, trace }

/// One line of the core's log.
class CoreLogLine {
  const CoreLogLine(this.message, {this.level = LogLevel.info});

  /// libbox entries carry a numeric level (0 = panic ... 6 = trace).
  factory CoreLogLine.leveled(int level, String message) => CoreLogLine(
    message,
    level: LogLevel.values[level.clamp(0, LogLevel.values.length - 1)],
  );

  /// A text line of the desktop core, e.g. `+0330 ... WARN [123] ...`.
  factory CoreLogLine.parse(String line) {
    final match = _levelPattern.firstMatch(line);
    return CoreLogLine(
      line,
      level: switch (match?.group(1)) {
        'PANIC' => LogLevel.panic,
        'FATAL' => LogLevel.fatal,
        'ERROR' => LogLevel.error,
        'WARN' => LogLevel.warn,
        'DEBUG' => LogLevel.debug,
        'TRACE' => LogLevel.trace,
        _ => LogLevel.info,
      },
    );
  }

  static final _levelPattern = RegExp(
    r'\b(PANIC|FATAL|ERROR|WARN|INFO|DEBUG|TRACE)\b',
  );

  final String message;
  final LogLevel level;

  bool get isProblem => level.index <= LogLevel.warn.index;
}
