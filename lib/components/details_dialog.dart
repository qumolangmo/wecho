/// Copyright (c) 2026 qumolangmo
///
/// License: MIT License with Commons Clause License Condition v1.0
/// see LICENSE-MIT and LICENSE-COMMONS-CLAUSE in the project root for full license text.
/// 
/// For commercial use, please contact: qumolangmo@gmail.com

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wecho/l10n/app_localizations.dart';
import 'package:wecho/l10n/app_localizations_zh.dart';
import 'package:wecho/view_models/dsp_controller_view_model.dart';


class DetailsDialog extends StatefulWidget {
  const DetailsDialog({super.key});

  @override
  State<DetailsDialog> createState() => _DetailsDialogState();
}

class _DetailsDialogState extends State<DetailsDialog> {
  String _version = 'Loading...';
  late final DSPControllerViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = DSPControllerViewModel();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    final version = await _viewModel.getAppVersion();
    setState(() {
      _version = version;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(AppLocalizations.of(context)!.info),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow(AppLocalizations.of(context)!.captureSampleRate, '44100 Hz'),
              _buildDetailRow(AppLocalizations.of(context)!.playbackSampleRate, '44099 Hz'),
              _buildDetailRow(AppLocalizations.of(context)!.captureBitDepth, '32bit'),
              _buildDetailRow(AppLocalizations.of(context)!.playbackBitDepth, '32bit'),
              _buildDetailRow(AppLocalizations.of(context)!.applicationVersion, 'v$_version'),
              const SizedBox(height: 20),
              _buildDetailRow(AppLocalizations.of(context)!.betaContaction, '1087859913'),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(AppLocalizations.of(context)!.close),
        ),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.grey[600],
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}