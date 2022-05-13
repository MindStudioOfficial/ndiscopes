import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:ndiscopes/config.dart';
import 'package:ndiscopes/service/ndi/ndi.dart';
import 'package:ndiscopes/util/datetimetostring.dart';
import 'package:ndiscopes/models/models.dart';
import 'dart:ffi';

void printGFX(String m) {
  if (kDebugMode) {
    print("[\x1B[32;1mGFX\x1B[0m] [\x1B[32m${DateTime.now().toTimeString()}\x1B[0m] $m");
  }
}

void checkGPU(BuildContext context) {
  final major = calloc<Int32>();
  final minor = calloc<Int32>();
  pixconvertCUDA.getDeviceProperties(major, minor);

  printGFX("GPU version ${major.value}.${minor.value}");
  if (major.value == 0) {
    Future.delayed(const Duration(seconds: 1), () {
      showDialog(
        context: context,
        builder: (context) {
          return SimpleDialog(
            backgroundColor: cDialogBackground,
            elevation: 0,
            title: Text(
              "Failed to check GPU version.",
              style: tDefault,
            ),
            children: [
              TextButton(
                style: bTextDefault,
                onPressed: () {
                  Navigator.pop(context);
                },
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    "OK",
                    style: tSmall,
                  ),
                ),
              ),
            ],
          );
        },
      );
    });
  } else if (major.value < appConfig.minMajorCC) {
    Future.delayed(const Duration(seconds: 1), () {
      showDialog(
        context: context,
        builder: (context) {
          return SimpleDialog(
            backgroundColor: cDialogBackground,
            elevation: 0,
            contentPadding: const EdgeInsets.all(8),
            title: Text(
              "Your GPU might not be supported",
              style: tDefault,
            ),
            children: [
              TextButton(
                style: bTextDefault,
                onPressed: () {
                  Navigator.pop(context);
                },
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    "OK",
                    style: tSmall,
                  ),
                ),
              ),
            ],
          );
        },
      );
    });
  }
  calloc.free(major);
  calloc.free(minor);
}
