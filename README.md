# NDIScopes

An open source Windows application to display several diffrent scopes/waveforms for an NDI® input built with [Flutter](https://flutter.dev). 

![GitHub all releases](https://img.shields.io/github/downloads/MindStudioOfficial/ndiscopes/total?style=flat-square)
![GitHub code size in bytes](https://img.shields.io/github/languages/code-size/MindStudioOfficial/ndiscopes?style=flat-square)
![GitHub contributors](https://img.shields.io/github/contributors/MindStudioOfficial/ndiscopes?style=flat-square)

![Screenshot](blob/sc4.jpg)

## Requirements

The software uses **CUDA** to compute the frames and scopes. A **NVIDIA GPU** is required to run this software. See *GPU Support* to see exaxtly what GPUs are supported.


## Roadmap

### Platform Support

- [x] Windows
- [ ] Linux
- [ ] MacOS

### Features

- [x] Waveforms
  - [x] Luma Waveform
  - [x] RGB Waveform
  - [x] RGB Parade
  - [x] UV Vectorscope  
- [x] Reference Frame
  - [x] Save/Load
  - [x] Overlay on source as splitscreen
  - [x] Overlay on scopes as background
  - [x] Overlay on scopes as splitscreen
  - [x] Show thumbnails in frame browse
- [x] Draw Masks on source/reference frame
- [ ] Record and graph RGBL ratio over time
- NDI Codec support
  - **This software now requests the frames to be in UYVY or BGRA format to maximize compatibility.**
  - [x] UYVY (most common, fastest)
  - [x] BGRA (stills and alpha)
  - others are very uncommon IMO
  

### GPU Support
- NVIDIA
  - [x] CC 8.x **Ampere** RTX 30 Series, RTX A Series,
  - [x] CC 7.x **Volta/Turing** RTX 20 Series, GTX 16 Series, RTX Quadro Series, TITAN RTX, TITAN V
  - [x] CC 6.x **Pascal** GTX 10 Series, Titan X, Quadro
  - [x] CC 5.x **Maxwell** GTX 750 - GTX 980 Ti
  - [x] CC >=3.5 **Kepler** GT 640 - GTX 780 Ti, TITAN Z 
  - [ ] CC <3.2 not supported by CUDA 11.x
- [ ] AMD
- [ ] other
  

## Download

Download the latest build under [Releases](https://github.com/MindStudioOfficial/ndiscopes/releases).

## Getting Started

For licensing reasons I am not able to provide the **SDK Files** directly. You have to source them yourself from [here](https://www.ndi.tv/sdk/#download).

The `.dll` file from the SDK goes into the bin folder once you have downloaded it.

This application uses the cross-platform [Flutter](https://flutter.dev/) framework written in [Dart](https://dart.dev/).

Upon building flutter puts the bin folder containing the necessary libraries in an assets folder which is incorrect. You will have to manually move the bin folder back to the root of the release folder once built.

### Run in Debug-Mode

```powershell
PS ..\ndiscopes> flutter pub get 

PS ..\ndiscopes> flutter run -d windows
```

### Build for Windows

```powershell
PS ..\ndiscopes> flutter build windows --release
```

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://flutter.dev/docs/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://flutter.dev/docs/cookbook)

For help getting started with Flutter, view our
[online documentation](https://flutter.dev/docs), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

### License

[License Agreement](license.md)
