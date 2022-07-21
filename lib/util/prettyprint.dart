extension ListPrint<E> on List<E> {
  String toPrettyString() {
    StringBuffer sb = StringBuffer();
    sb.writeln("List \x1B[36m$E\x1B[0m [\x1B[34m$length\x1B[0m]:");
    sb.writeln("[");
    for (int i = 0; i < this.length; i++) {
      sb.writeln("\x1B[32m$i\x1B[0m: " + this[i].toString() + ",");
    }
    sb.write("]");
    String s = sb.toString();
    s = s.replaceAll(",\n]", "\n]");
    return s;
  }
}
