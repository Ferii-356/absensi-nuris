import 'package:flutter/material.dart';
import '../models/santri_model.dart';
import 'entrance_animation.dart';

class SantriCard extends StatefulWidget {
  final SantriModel santri;
  final VoidCallback? onTap;

  const SantriCard({super.key, required this.santri, this.onTap});

  @override
  State<SantriCard> createState() => _SantriCardState();
}

class _SantriCardState extends State<SantriCard> {
  bool _ditekan = false;

  @override
  Widget build(BuildContext context) {
    return EntranceAnimation(
      child: Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: widget.onTap,
          onHighlightChanged: (value) => setState(() => _ditekan = value),
          child: AnimatedScale(
            scale: _ditekan ? 0.98 : 1.0,
            duration: const Duration(milliseconds: 120),
            curve: Curves.easeOut,
            child: ListTile(
              title: Text(widget.santri.nama),
              subtitle: Text('NIM: ${widget.santri.nim}'),
            ),
          ),
        ),
      ),
    );
  }
}