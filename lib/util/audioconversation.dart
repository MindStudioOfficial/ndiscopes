import 'dart:math';

double dBUfromFloat(double input) {
  return 20 * log10(input / 0.81372) + 2.21;
}

double log10(double x) => log(x) / ln10;
