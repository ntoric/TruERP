import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_exception.dart';
import '../widgets/common.dart';

/// Downloads a server-generated PDF (with auth headers) and opens the
/// system share sheet, from which the user can view, print or send it.
Future<void> sharePdf(
  BuildContext context,
  ApiClient api,
  String path,
  String fileName,
) => shareFile(context, api, path, fileName);

/// Downloads any server-generated file (PDF, Excel, CSV) and shares it.
Future<void> shareFile(
  BuildContext context,
  ApiClient api,
  String path,
  String fileName, {
  Map<String, dynamic>? query,
  String mimeType = 'application/pdf',
}) async {
  final messenger = ScaffoldMessenger.of(context);
  messenger.showSnackBar(
    const SnackBar(
      content: Text('Preparing file…'),
      duration: Duration(seconds: 30),
    ),
  );
  try {
    final dir = await getTemporaryDirectory();
    final safe = fileName.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    final file = File('${dir.path}/$safe');
    await api.download(path, file.path, query: query);
    messenger.hideCurrentSnackBar();
    if (!context.mounted) return;
    final box = context.findRenderObject() as RenderBox?;
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: mimeType)],
        subject: fileName,
        sharePositionOrigin: box == null
            ? null
            : box.localToGlobal(Offset.zero) & box.size,
      ),
    );
  } catch (e) {
    messenger.hideCurrentSnackBar();
    if (context.mounted) showSnack(context, errorMessage(e), error: true);
  }
}

String _digits(String phone) => phone.replaceAll(RegExp(r'[^0-9+]'), '');

Future<void> callPhone(BuildContext context, String phone) =>
    _launch(context, Uri.parse('tel:${_digits(phone)}'));

/// Opens WhatsApp chat; 10-digit numbers are assumed Indian (+91).
Future<void> openWhatsApp(
  BuildContext context,
  String phone, {
  String text = '',
}) {
  var d = _digits(phone).replaceAll('+', '');
  if (d.length == 10) d = '91$d';
  return _launch(
    context,
    Uri.parse(
      'https://wa.me/$d${text.isEmpty ? '' : '?text=${Uri.encodeComponent(text)}'}',
    ),
  );
}

Future<void> sendEmail(BuildContext context, String email) =>
    _launch(context, Uri.parse('mailto:$email'));

Future<void> _launch(BuildContext context, Uri uri) async {
  final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!ok && context.mounted) {
    showSnack(context, 'No app available to open this', error: true);
  }
}
