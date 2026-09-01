import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class ReportPhotoAttachment extends StatelessWidget {
  final File? image;
  final ValueChanged<File?> onChanged;
  final bool enabled;
  final String title;
  final String subtitle;

  const ReportPhotoAttachment({
    super.key,
    required this.image,
    required this.onChanged,
    this.enabled = true,
    this.title = "Proof photo",
    this.subtitle = "Optional — attach a photo for this update",
  });

  static const _ink = Color(0xFF0F172A);
  static const _muted = Color(0xFF64748B);
  static const _accent = Color(0xFF0025CC);
  static const _surface = Color(0xFFF8FAFC);
  static const _border = Color(0xFFE2E8F0);

  Future<void> _pick(BuildContext context, ImageSource source) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: source,
      imageQuality: 80,
    );
    if (picked != null) {
      onChanged(File(picked.path));
    }
  }

  Future<void> _showOptions(BuildContext context) async {
    if (!enabled) return;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: _border,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: _ink,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13,
                    color: _muted,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 18),
                _SourceTile(
                  icon: Icons.photo_camera_rounded,
                  iconBg: const Color(0xFFEFF6FF),
                  iconColor: const Color(0xFF2563EB),
                  label: "Take photo",
                  onTap: () async {
                    Navigator.pop(sheetContext);
                    await _pick(context, ImageSource.camera);
                  },
                ),
                const SizedBox(height: 8),
                _SourceTile(
                  icon: Icons.photo_library_rounded,
                  iconBg: const Color(0xFFF0FDF4),
                  iconColor: const Color(0xFF16A34A),
                  label: "Choose from gallery",
                  onTap: () async {
                    Navigator.pop(sheetContext);
                    await _pick(context, ImageSource.gallery);
                  },
                ),
                if (image != null) ...[
                  const SizedBox(height: 8),
                  _SourceTile(
                    icon: Icons.delete_outline_rounded,
                    iconBg: const Color(0xFFFEF2F2),
                    iconColor: const Color(0xFFDC2626),
                    label: "Remove photo",
                    onTap: () {
                      Navigator.pop(sheetContext);
                      onChanged(null);
                    },
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (image != null) {
      return _AttachedPreview(
        image: image!,
        enabled: enabled,
        onTap: () => _showOptions(context),
        onRemove: enabled ? () => onChanged(null) : null,
      );
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? () => _showOptions(context) : null,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: enabled ? const Color(0xFFBFDBFE) : _border,
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: enabled
                        ? [
                            _accent.withValues(alpha: 0.12),
                            const Color(0xFF2563EB).withValues(alpha: 0.08),
                          ]
                        : [_border, _border],
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.add_a_photo_rounded,
                  color: enabled ? _accent : _muted,
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Add photo",
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: enabled ? _ink : _muted,
                      ),
                    ),
                    const SizedBox(height: 3),
                    const Text(
                      "Optional · Camera or gallery",
                      style: TextStyle(
                        fontSize: 12.5,
                        color: _muted,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: enabled ? _accent : _border,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AttachedPreview extends StatelessWidget {
  final File image;
  final bool enabled;
  final VoidCallback onTap;
  final VoidCallback? onRemove;

  const _AttachedPreview({
    required this.image,
    required this.enabled,
    required this.onTap,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFBFDBFE), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(14),
                ),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Image.file(
                    image,
                    fit: BoxFit.cover,
                    width: double.infinity,
                  ),
                ),
              ),
              Positioned(
                top: 10,
                left: 10,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFF16A34A),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_rounded, color: Colors.white, size: 14),
                      SizedBox(width: 4),
                      Text(
                        "Attached",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (onRemove != null)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Material(
                    color: Colors.black.withValues(alpha: 0.45),
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: onRemove,
                      child: const Padding(
                        padding: EdgeInsets.all(6),
                        child: Icon(
                          Icons.close_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: enabled ? onTap : null,
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(14),
              ),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  children: [
                    const Icon(
                      Icons.edit_outlined,
                      size: 18,
                      color: ReportPhotoAttachment._accent,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        enabled ? "Tap to change photo" : "Photo attached",
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: enabled
                              ? ReportPhotoAttachment._accent
                              : ReportPhotoAttachment._muted,
                        ),
                      ),
                    ),
                    if (enabled)
                      const Icon(
                        Icons.chevron_right_rounded,
                        color: ReportPhotoAttachment._accent,
                        size: 20,
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SourceTile extends StatelessWidget {
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String label;
  final VoidCallback onTap;

  const _SourceTile({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF8FAFC),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: ReportPhotoAttachment._ink,
                  ),
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: ReportPhotoAttachment._muted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
