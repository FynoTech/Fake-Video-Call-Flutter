import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../app/theme/app_colors.dart';
import 'call_opening_loader.dart';

/// Runs [task] while showing a blur + card on a [Dialog] route.
///
/// The dialog is always closed in `finally` with the [NavigatorState] captured
/// when the route opens — never [Get.isDialogOpen] / [Get.back] (they desync).
///
/// **Navigation:** Do not call [Get.back], [Get.toNamed], etc. from [task] while
/// this dialog is the top route — that would pop or push over the wrong layer.
/// Run navigation only *after* this function returns.
Future<T?> showAdLoadingDialog<T>({
  required Future<T> Function() task,
  String title = 'Ad Loading',
  String subtitle = '',
  double indicatorSize = 72,
}) async {
  final navigatorContext = Get.context;
  if (navigatorContext == null || !navigatorContext.mounted) {
    if (kDebugMode) {
      debugPrint('[AdLoadingDialog] No context; running task without overlay.');
    }
    return task();
  }

  Object? outcome;
  Object? caught;
  StackTrace? caughtStack;

  await showDialog<void>(
    context: navigatorContext,
    barrierDismissible: false,
    barrierColor: AppColors.black.withValues(alpha: 0.16),
    useRootNavigator: true,
    builder: (dialogContext) {
      final navigator = Navigator.of(dialogContext, rootNavigator: true);

      void startWork() {
        Future<void> run() async {
          try {
            outcome = await task();
          } catch (e, st) {
            caught = e;
            caughtStack = st;
            if (kDebugMode) {
              debugPrint('[AdLoadingDialog] task error: $e\n$st');
            }
          } finally {
            if (navigator.mounted && navigator.canPop()) {
              navigator.pop();
            }
          }
        }

        unawaited(run());
      }

      WidgetsBinding.instance.addPostFrameCallback((_) => startWork());

      return PopScope(
        canPop: false,
        child: Material(
          type: MaterialType.transparency,
          child: SizedBox.expand(
            child: Stack(
              fit: StackFit.expand,
              children: [
                const SizedBox.expand(),
                Center(
                  child: CallOpeningLoader(
                    title: title,
                    subtitle: subtitle,
                    showCard: true,
                    indicatorSize: indicatorSize,
                    cardOpacity: 0.82,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );

  if (caught != null) {
    if (caughtStack != null) {
      Error.throwWithStackTrace(caught!, caughtStack!);
    }
    throw caught!;
  }
  return outcome as T?;
}
