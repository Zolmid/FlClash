import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'checkout.dart';

class PaymentQrView extends StatefulWidget {
  const PaymentQrView({
    super.key,
    required this.qr,
    required this.instruction,
    required this.expiredLabel,
    this.now = DateTime.now,
  });

  final PaymentQr qr;
  final String instruction;
  final String expiredLabel;
  final DateTime Function() now;

  @override
  State<PaymentQrView> createState() => _PaymentQrViewState();
}

class _PaymentQrViewState extends State<PaymentQrView> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!widget.qr.isValidAt(widget.now())) {
        timer.cancel();
        setState(() {});
      }
    });
  }

  @override
  void didUpdateWidget(PaymentQrView oldWidget) {
    super.didUpdateWidget(oldWidget);
    _startTimer();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.qr.isValidAt(widget.now())) {
      return Text(widget.expiredLabel);
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ExcludeSemantics(
          child: QrImageView(
            data: widget.qr.payload,
            size: 232,
            backgroundColor: const Color(0xffffffff),
          ),
        ),
        const SizedBox(height: 12),
        Text(widget.instruction, textAlign: TextAlign.center),
      ],
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
