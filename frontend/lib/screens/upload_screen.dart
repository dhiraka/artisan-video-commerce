import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/upload_provider.dart';
import '../services/api_service.dart';

class UploadScreen extends StatefulWidget {
  const UploadScreen({super.key});

  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _priceController = TextEditingController();
  final _nameController = TextEditingController();
  final _tagsController = TextEditingController();

  String? _titleError;
  Timer? _titleDebounce;

  @override
  void initState() {
    super.initState();
    final provider = context.read<UploadProvider>();
    _titleController.text = provider.savedTitle;
    _descController.text = provider.savedDesc;
    _priceController.text = provider.savedPrice;
    _nameController.text = provider.savedName;
    _tagsController.text = provider.savedTags;

    for (final c in [_titleController, _descController, _priceController, _nameController, _tagsController]) {
      c.addListener(_saveFormValues);
    }
    _titleController.addListener(_onTitleChanged);
  }

  void _onTitleChanged() {
    _titleDebounce?.cancel();
    final title = _titleController.text.trim();
    if (title.length < 3) {
      if (_titleError != null) setState(() => _titleError = null);
      return;
    }
    _titleDebounce = Timer(const Duration(milliseconds: 600), () async {
      try {
        final exists = await ApiService().checkTitleExists(title);
        if (mounted) {
          setState(() => _titleError = exists ? 'A product with this title already exists' : null);
        }
      } catch (_) {}
    });
  }

  void _saveFormValues() {
    context.read<UploadProvider>().saveFormValues(
      title: _titleController.text,
      desc: _descController.text,
      price: _priceController.text,
      name: _nameController.text,
      tags: _tagsController.text,
    );
  }

  @override
  void dispose() {
    _titleDebounce?.cancel();
    _titleController.dispose();
    _descController.dispose();
    _priceController.dispose();
    _nameController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<UploadProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('List Your Craft')),
      body: _buildBody(context, provider),
    );
  }

  Widget _buildBody(BuildContext context, UploadProvider provider) {
    switch (provider.step) {
      case UploadStep.uploading:
      case UploadStep.creatingProduct:
      case UploadStep.transcoding:
        return _ProgressView(provider: provider);

      case UploadStep.done:
        return _DoneView(provider: provider);

      case UploadStep.error:
        return _ErrorView(message: provider.errorMessage ?? 'Unknown error', onRetry: () {
          context.read<UploadProvider>().reset();
        });

      default:
        return _UploadForm(
          formKey: _formKey,
          titleController: _titleController,
          descController: _descController,
          priceController: _priceController,
          nameController: _nameController,
          tagsController: _tagsController,
          provider: provider,
          titleError: _titleError,
        );
    }
  }
}

class _UploadForm extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController titleController;
  final TextEditingController descController;
  final TextEditingController priceController;
  final TextEditingController nameController;
  final TextEditingController tagsController;
  final UploadProvider provider;
  final String? titleError;

  const _UploadForm({
    required this.formKey,
    required this.titleController,
    required this.descController,
    required this.priceController,
    required this.nameController,
    required this.tagsController,
    required this.provider,
    this.titleError,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Product Details', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            TextFormField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Your Name / Studio Name', prefixIcon: Icon(Icons.person)),
              validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: titleController,
              decoration: InputDecoration(
                labelText: 'Product Title',
                prefixIcon: const Icon(Icons.title),
                errorText: titleError,
              ),
              validator: (v) {
                if (v == null || v.trim().length < 3) return 'At least 3 characters';
                if (titleError != null) return titleError;
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: descController,
              decoration: const InputDecoration(
                labelText: 'Description',
                prefixIcon: Icon(Icons.description),
                alignLabelWithHint: true,
              ),
              maxLines: 4,
              validator: (v) => v == null || v.trim().length < 10 ? 'At least 10 characters' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: priceController,
              decoration: const InputDecoration(
                labelText: 'Price (INR)',
                prefixIcon: Icon(Icons.currency_rupee),
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              validator: (v) {
                final d = double.tryParse(v ?? '');
                if (d == null || d <= 0) return 'Enter a valid price';
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: tagsController,
              decoration: const InputDecoration(
                labelText: 'Tags (comma-separated)',
                prefixIcon: Icon(Icons.label_outline),
                hintText: 'pottery, ceramics, handmade',
              ),
            ),
            const SizedBox(height: 24),
            // Video picker area
            GestureDetector(
              onTap: () => context.read<UploadProvider>().pickVideo(),
              child: Container(
                height: 160,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outline,
                    width: 2,
                    style: BorderStyle.solid,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  color: Theme.of(context).colorScheme.surfaceContainerLowest,
                ),
                child: provider.selectedFile != null
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.videocam, size: 48, color: Colors.green),
                          const SizedBox(height: 8),
                          Text(
                            provider.selectedFile!.name,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                            textAlign: TextAlign.center,
                          ),
                          Text(
                            _formatBytes(provider.selectedFile!.size),
                            style: const TextStyle(color: Colors.grey),
                          ),
                        ],
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.cloud_upload_outlined,
                              size: 48,
                              color: Theme.of(context).colorScheme.primary),
                          const SizedBox(height: 8),
                          const Text('Tap to select your process video',
                              textAlign: TextAlign.center),
                          const SizedBox(height: 4),
                          Text(
                            'MP4, MOV, AVI, MKV — up to 15 minutes',
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: (provider.selectedFile == null || titleError != null)
                  ? null
                  : () => _submit(context),
              icon: const Icon(Icons.upload),
              label: const Text('Upload & List Product'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _submit(BuildContext context) {
    if (!formKey.currentState!.validate()) return;
    final tags = tagsController.text
        .split(',')
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .toList();
    context.read<UploadProvider>().uploadAndCreate(
      title: titleController.text.trim(),
      description: descController.text.trim(),
      price: double.parse(priceController.text.trim()),
      tags: tags,
      artisanName: nameController.text.trim(),
    );
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
}

class _ProgressView extends StatelessWidget {
  final UploadProvider provider;
  const _ProgressView({required this.provider});

  @override
  Widget build(BuildContext context) {
    String title;
    String subtitle;
    Widget indicator;

    switch (provider.step) {
      case UploadStep.uploading:
        final pct = (provider.uploadProgress * 100).toStringAsFixed(0);
        title = 'Uploading Video';
        subtitle = '$pct% complete';
        indicator = LinearProgressIndicator(value: provider.uploadProgress);
      case UploadStep.creatingProduct:
        title = 'Creating Product';
        subtitle = 'Saving your product details...';
        indicator = const CircularProgressIndicator();
      case UploadStep.transcoding:
        title = 'Processing Video';
        subtitle = 'Creating adaptive HLS streams for all network speeds.\nThis may take a few minutes.';
        indicator = const CircularProgressIndicator();
      default:
        return const SizedBox.shrink();
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            indicator,
            const SizedBox(height: 24),
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DoneView extends StatelessWidget {
  final UploadProvider provider;
  const _DoneView({required this.provider});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_rounded,
                size: 80, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 24),
            Text('Product Listed!',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
              '${provider.product?.title ?? "Your product"} has been listed! The video is being processed and will be ready to watch within 10–20 minutes.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: () => context.read<UploadProvider>().reset(),
              icon: const Icon(Icons.add),
              label: const Text('List Another Product'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text('Upload Failed', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 24),
            FilledButton(onPressed: onRetry, child: const Text('Try Again')),
          ],
        ),
      ),
    );
  }
}
