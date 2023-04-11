# CodjX Suite Writer

Bringing desktop-like editing experience to iPad, available on [App Store](https://apps.apple.com/us/app/code-app/id1512938504) and [TestFlight](https://testflight.apple.com/join/EgZ8sE2P).

![CodjX Suite Writer Screenshot](https://thebaselab.com/code/clang.png)

## About the repository

This repository contains the source code of the app. We also work on issues, listen to your feedback and publish our development plan here.

## Documentation

See [Wiki](https://github.com/thebaselab/codeapp/wiki)

## The Plan

Use [VS Code](https://github.com/microsoft/vscode) as a design template while providing key functionalities with [monaco-editor](https://github.com/microsoft/monaco-editor) and native code:

- Version Control (Git clone, commits, diff editor, push, pull and gutter indicator) ✅
- Embeded terminal (70+ commands avaliable) ✅
- Local web development environment (Node + PHP) ✅
- Built in Python runtime ✅
- C/C++ Runtime with WebAssembly (with clang support) ✅
- SSH Support ✅
- [LSP](https://microsoft.github.io/language-server-protocol) support 🏃

## Building the project

1. `git clone https://github.com/thebaselab/codeapp`
2. `./downloadFrameworks.sh`
3. Open Code.xcodeproj
4. Switch to CodeUI target if you wish to run the app on a simulator
5. Click build

The source code of the built-in languages are hosted on these repositories.
| Language | Repository |
|-----------------|-------------------|
| Python 3.9.2 | [cpython](https://github.com/holzschu/cpython/tree/3.9)|
| Clang 14.0.0 | [llvm-project](https://github.com/holzschu/llvm-project)|
| PHP 8.0.8 | [php-src](https://github.com/bummoblizard/php-src/tree/PHP-8.0.8)|
| Node.js 16.14.2 | [nodejs-mobile](https://github.com/1Conan/nodejs-mobile/tree/upstream-node-v16.14.x-ios)|
