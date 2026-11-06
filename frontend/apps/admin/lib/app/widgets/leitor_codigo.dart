import 'package:core/core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// No navegador, a câmera só é liberada em HTTPS ou em localhost (regra dos navegadores).
bool get cameraDisponivel =>
    !kIsWeb || Uri.base.scheme == 'https' || const {'localhost', '127.0.0.1'}.contains(Uri.base.host);

/// Lê um código de barras ou QR Code pela câmera, ou digitado / leitor USB.
/// Retorna o código lido, ou null se cancelado.
Future<String?> lerCodigo(BuildContext context) =>
    showDialog<String>(context: context, builder: (_) => const _LeitorCodigoDialog());

class _LeitorCodigoDialog extends StatefulWidget {
  const _LeitorCodigoDialog();

  @override
  State<_LeitorCodigoDialog> createState() => _LeitorCodigoDialogState();
}

class _LeitorCodigoDialogState extends State<_LeitorCodigoDialog> {
  final _digitado = TextEditingController();
  MobileScannerController? _camera;
  bool _concluido = false;

  @override
  void initState() {
    super.initState();
    if (cameraDisponivel) {
      _camera = MobileScannerController(detectionSpeed: DetectionSpeed.noDuplicates);
    }
  }

  @override
  void dispose() {
    _camera?.dispose();
    _digitado.dispose();
    super.dispose();
  }

  void _concluir(String? codigo) {
    final valor = codigo?.trim() ?? '';
    if (_concluido || valor.isEmpty) return;
    _concluido = true;
    Navigator.pop(context, valor);
  }

  @override
  Widget build(BuildContext context) {
    final camera = _camera;
    return AlertDialog(
      title: const Text('Ler código de barras / QR Code'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (camera != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  height: 280,
                  child: MobileScanner(
                    controller: camera,
                    onDetect: (captura) => _concluir(captura.barcodes.firstOrNull?.rawValue),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text('Aponte a câmera para o código.',
                  textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade700)),
              const SizedBox(height: 16),
            ] else
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppCores.ambar.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'A câmera do navegador só funciona com HTTPS. Use um leitor de código de barras USB '
                  '(ele digita o código sozinho), digite o código abaixo ou use o aplicativo Android.',
                ),
              ),
            TextField(
              controller: _digitado,
              // Sem câmera, o foco já fica aqui para o leitor USB "digitar" o código e apertar Enter.
              autofocus: camera == null,
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(
                labelText: 'Código',
                hintText: 'Digite ou use o leitor USB',
                prefixIcon: Icon(Icons.keyboard),
              ),
              onSubmitted: _concluir,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(onPressed: () => _concluir(_digitado.text), child: const Text('Usar código')),
      ],
    );
  }
}
