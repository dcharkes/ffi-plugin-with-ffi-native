// ignore_for_file: constant_identifier_names

import 'dart:async';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';

import 'package:native_assets_cli/native_assets_cli.dart';
import 'package:ffi/ffi.dart';
import 'my_plugin_bindings_generated.dart' as bindings;

/// A very short-lived native function.
///
/// For very short-lived functions, it is fine to call them on the main isolate.
/// They will block the Dart execution while running the native function, so
/// only do this for native functions which are guaranteed to be short-lived.
int sum(int a, int b) {
  ensureDylibGloballyOpened();
  return bindings.sum(a, b);
}

/// A longer lived native function, which occupies the thread calling it.
///
/// Do not call these kind of native functions in the main isolate. They will
/// block Dart execution. This will cause dropped frames in Flutter applications.
/// Instead, call these native functions on a separate isolate.
///
/// Modify this to suit your own use case. Example use cases:
///
/// 1. Reuse a single isolate for various different kinds of requests.
/// 2. Use multiple helper isolates for parallel execution.
Future<int> sumAsync(int a, int b) async {
  ensureDylibGloballyOpened();
  final SendPort helperIsolateSendPort = await _helperIsolateSendPort;
  final int requestId = _nextSumRequestId++;
  final _SumRequest request = _SumRequest(requestId, a, b);
  final Completer<int> completer = Completer<int>();
  _sumRequests[requestId] = completer;
  helperIsolateSendPort.send(request);
  return completer.future;
}

const String _libName = 'my_plugin';

/// On Linux and Android.
const RTLD_LAZY = 0x00001;

/// On Android Arm.
const RTLD_GLOBAL_android_arm32 = 0x00002;

/// On Linux and Android Arm64.
const RTLD_GLOBAL_rest = 0x00100;

final RTLD_GLOBAL = Abi.current() == Abi.androidArm
    ? RTLD_GLOBAL_android_arm32
    : RTLD_GLOBAL_rest;

final RTLD_DEFAULT_android = Pointer<Void>.fromAddress(0);

@Native<Pointer<Void> Function(Pointer<Char>, Int)>()
external Pointer<Void> dlopen(Pointer<Char> file, int mode);

@Native<Pointer<Void> Function(Pointer<Void>, Pointer<Char>)>()
external Pointer<Void> dlsym(Pointer<Void> handle, Pointer<Char> symbol);

Object? _cache;

void ensureDylibGloballyOpened() {
  assert(Platform.isAndroid);
  if (_cache != null) {
    return;
  }

  final dylibName = Target.current.os.dylibFileName(_libName);
  return using((arena) {
    // DynamicLibrary.process() is the same as RTLD_DEFAULT.
    // Looking up with DynamicLibrary.process() should fail at this point.
    final sumHandleInDefault1 = dlsym(
        RTLD_DEFAULT_android, 'sum'.toNativeUtf8(allocator: arena).cast());
    print(['sumHandleInDefault1', sumHandleInDefault1]);
    final providesSum1 = DynamicLibrary.process().providesSymbol('sum');
    print(['providesSum1', providesSum1]);

    print('Globally opening $dylibName.');
    final dylibHandle = dlopen(dylibName.toNativeUtf8(allocator: arena).cast(),
        RTLD_LAZY | RTLD_GLOBAL);
    print(['dylibHandle', dylibHandle]);
    _cache = dylibHandle;

    // Now lookup should succeed.
    // It succeeds with directly calling dlsym.
    final sumHandleInDefault2 = dlsym(
        RTLD_DEFAULT_android, 'sum'.toNativeUtf8(allocator: arena).cast());
    print(['sumHandleInDefault2', sumHandleInDefault2]);
    // But it fails with `DynamicLibrary.process()` on the emulator.
    // On an arm64 Android device this succeeds.
    final providesSum2 = DynamicLibrary.process().providesSymbol('sum');
    if (!providesSum2) {
      throw Exception('"sum" is not available in the Process');
    }
  });
}

/// A request to compute `sum`.
///
/// Typically sent from one isolate to another.
class _SumRequest {
  final int id;
  final int a;
  final int b;

  const _SumRequest(this.id, this.a, this.b);
}

/// A response with the result of `sum`.
///
/// Typically sent from one isolate to another.
class _SumResponse {
  final int id;
  final int result;

  const _SumResponse(this.id, this.result);
}

/// Counter to identify [_SumRequest]s and [_SumResponse]s.
int _nextSumRequestId = 0;

/// Mapping from [_SumRequest] `id`s to the completers corresponding to the correct future of the pending request.
final Map<int, Completer<int>> _sumRequests = <int, Completer<int>>{};

/// The SendPort belonging to the helper isolate.
Future<SendPort> _helperIsolateSendPort = () async {
  // The helper isolate is going to send us back a SendPort, which we want to
  // wait for.
  final Completer<SendPort> completer = Completer<SendPort>();

  // Receive port on the main isolate to receive messages from the helper.
  // We receive two types of messages:
  // 1. A port to send messages on.
  // 2. Responses to requests we sent.
  final ReceivePort receivePort = ReceivePort()
    ..listen((dynamic data) {
      if (data is SendPort) {
        // The helper isolate sent us the port on which we can sent it requests.
        completer.complete(data);
        return;
      }
      if (data is _SumResponse) {
        // The helper isolate sent us a response to a request we sent.
        final Completer<int> completer = _sumRequests[data.id]!;
        _sumRequests.remove(data.id);
        completer.complete(data.result);
        return;
      }
      throw UnsupportedError('Unsupported message type: ${data.runtimeType}');
    });

  // Start the helper isolate.
  await Isolate.spawn((SendPort sendPort) async {
    final ReceivePort helperReceivePort = ReceivePort()
      ..listen((dynamic data) {
        // On the helper isolate listen to requests and respond to them.
        if (data is _SumRequest) {
          final int result = bindings.sum_long_running(data.a, data.b);
          final _SumResponse response = _SumResponse(data.id, result);
          sendPort.send(response);
          return;
        }
        throw UnsupportedError('Unsupported message type: ${data.runtimeType}');
      });

    // Send the port to the main isolate on which we can receive requests.
    sendPort.send(helperReceivePort.sendPort);
  }, receivePort.sendPort);

  // Wait until the helper isolate has sent us back the SendPort on which we
  // can start sending requests.
  return completer.future;
}();
