import 'package:flutter/material.dart';

Widget buildFluxRuntimeErrorWidget(FlutterErrorDetails details) {
  return Directionality(
    textDirection: TextDirection.ltr,
    child: Material(
      color: const Color(0xFFF3F8FB),
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Container(
              margin: const EdgeInsets.all(20),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFBDD8E7)),
              ),
              child: DefaultTextStyle(
                style: const TextStyle(
                  color: Color(0xFF20313D),
                  fontSize: 15,
                  height: 1.4,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '页面加载异常',
                      style: TextStyle(
                        color: Color(0xFF164B66),
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text('Flux 已拦截这次页面错误。请返回后重新进入；若仍出现，把以下错误内容反馈给开发者。'),
                    const SizedBox(height: 12),
                    SelectableText(
                      details.exceptionAsString(),
                      style: const TextStyle(
                        color: Color(0xFF526A78),
                        fontSize: 12,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
