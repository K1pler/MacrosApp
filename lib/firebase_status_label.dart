import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FirebaseStatusIcon extends StatefulWidget {
  const FirebaseStatusIcon({super.key});

  @override
  State<FirebaseStatusIcon> createState() => _FirebaseStatusIconState();
}

class _FirebaseStatusIconState extends State<FirebaseStatusIcon> {
  bool? _connected;
  Timer? _timer;
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    _checkConnection();
    _timer = Timer.periodic(const Duration(seconds: 10), (_) => _checkConnection());
  }

  Future<void> _checkConnection() async {
    setState(() { _checking = true; });
    try {
      await FirebaseFirestore.instance.collection('alimentos').limit(1).get();
      setState(() {
        _connected = true;
        _checking = false;
      });
    } catch (e) {
      setState(() {
        _connected = false;
        _checking = false;
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _showConnectionDialog() {
    showDialog(
      context: context,
      builder: (context) {
        Color color;
        IconData icon;
        String text;
        if (_connected == null) {
          color = Colors.grey;
          icon = Icons.help_outline;
          text = 'Comprobando conexión a Firebase...';
        } else if (_connected == true) {
          color = Colors.green;
          icon = Icons.check_circle_outline;
          text = 'Conectado a Firebase';
        } else {
          color = Colors.red;
          icon = Icons.cancel_outlined;
          text = 'Sin conexión a Firebase';
        }
        return AlertDialog(
          backgroundColor: Colors.grey[900],
          title: Row(
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(width: 8),
              Text('Estado de conexión', style: TextStyle(color: color)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 48),
              const SizedBox(height: 12),
              Text(
                text,
                style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                'La app necesita conexión con Firebase para funcionar correctamente. Si tienes problemas de conexión, revisa tu red o vuelve a intentarlo.',
                style: const TextStyle(color: Colors.white70, fontSize: 13),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: _checking ? null : _checkConnection,
              child: _checking
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Reintentar', style: TextStyle(color: Colors.red)),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cerrar', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    Color color;
    IconData icon;
    String tooltip;
    if (_connected == null) {
      color = Colors.grey;
      icon = Icons.help_outline;
      tooltip = 'Comprobando conexión a Firebase...';
    } else if (_connected == true) {
      color = Colors.green;
      icon = Icons.check_circle_outline;
      tooltip = 'Conectado a Firebase';
    } else {
      color = Colors.red;
      icon = Icons.cancel_outlined;
      tooltip = 'Sin conexión a Firebase';
    }
    return IconButton(
      icon: Icon(icon, color: color),
      tooltip: tooltip,
      onPressed: _showConnectionDialog,
    );
  }
} 