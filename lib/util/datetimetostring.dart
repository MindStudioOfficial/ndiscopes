extension DateTimeString on DateTime {
  String toDateString() {
    String s = "";
    s += day > 9 ? day.toString() : "0" + day.toString();
    s += ".";
    s += month > 9 ? month.toString() : "0" + month.toString();
    s += ".";
    s += year.toString();
    return s;
  }

  String toTimeString() {
    String s = "";
    s += hour > 9 ? hour.toString() : "0" + hour.toString();
    s += ":";
    s += minute > 9 ? minute.toString() : "0" + minute.toString();
    return s;
  }

  String toDateTimeString(String seperator) {
    String s = "";
    s += toDateString();
    s += seperator;
    s += toTimeString();
    return s;
  }

  String toDateShortString() {
    String s = "";
    s += year.toString();
    s += month > 9 ? month.toString() : "0" + month.toString();
    s += day > 9 ? day.toString() : "0" + day.toString();

    return s;
  }

  String toDateTimeShortString() {
    String s = "";
    s += toDateShortString();
    s += "_";
    s += hour > 9 ? hour.toString() : "0" + hour.toString();
    s += minute > 9 ? minute.toString() : "0" + minute.toString();
    s += second > 9 ? second.toString() : "0" + second.toString();

    return s;
  }
}
