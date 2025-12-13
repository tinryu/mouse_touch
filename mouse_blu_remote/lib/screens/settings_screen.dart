import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/connection_provider.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF0F172A),
              const Color(0xFF1E293B),
              const Color(0xFF334155),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(context),
              Expanded(
                child: _buildSettings(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back, color: Colors.white),
          ),
          const SizedBox(width: 8),
          Text(
            'Settings',
            style: GoogleFonts.inter(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettings() {
    return Consumer<ConnectionProvider>(
      builder: (context, provider, _) {
        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            _buildSection(
              title: 'Mouse Control',
              children: [
                _buildSliderSetting(
                  label: 'Sensitivity',
                  value: provider.sensitivity,
                  min: 0.5,
                  max: 3.0,
                  divisions: 25,
                  onChanged: (value) => provider.setSensitivity(value),
                ),
                const SizedBox(height: 16),
                _buildSliderSetting(
                  label: 'Scroll Speed',
                  value: provider.scrollSpeed,
                  min: 0.5,
                  max: 3.0,
                  divisions: 25,
                  onChanged: (value) => provider.setScrollSpeed(value),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildSection(
              title: 'Feedback',
              children: [
                _buildSwitchSetting(
                  label: 'Haptic Feedback',
                  subtitle: 'Vibrate on clicks',
                  value: provider.hapticFeedback,
                  onChanged: (value) => provider.setHapticFeedback(value),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildSection(
              title: 'Connection',
              children: [
                _buildInfoTile(
                  icon: Icons.bluetooth,
                  label: 'Connection Mode',
                  value: provider.mode == ConnectionMode.bluetooth
                      ? 'Bluetooth'
                      : 'WiFi',
                ),
                if (provider.mode == ConnectionMode.websocket) ...[
                  const SizedBox(height: 12),
                  _buildInfoTile(
                    icon: Icons.computer,
                    label: 'Server Address',
                    value: '${provider.serverHost}:${provider.serverPort}',
                  ),
                ],
              ],
            ),
            const SizedBox(height: 24),
            _buildSection(
              title: 'About',
              children: [
                _buildInfoTile(
                  icon: Icons.info_outline,
                  label: 'Version',
                  value: '1.0.0',
                ),
                const SizedBox(height: 12),
                _buildInfoTile(
                  icon: Icons.code,
                  label: 'Developer',
                  value: 'Mouse Remote Team',
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildSection({required String title, required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildSliderSetting({
    required String label,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required ValueChanged<double> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 16,
                color: Colors.white,
              ),
            ),
            Text(
              value.toStringAsFixed(1),
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.cyan.shade400,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SliderTheme(
          data: SliderThemeData(
            activeTrackColor: Colors.cyan.shade400,
            inactiveTrackColor: Colors.white.withOpacity(0.2),
            thumbColor: Colors.cyan.shade400,
            overlayColor: Colors.cyan.withOpacity(0.2),
          ),
          child: Slider(
            value: value,
            min: min,
            max: max,
            divisions: divisions,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  Widget _buildSwitchSetting({
    required String label,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 16,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: Colors.white60,
                ),
              ),
            ],
          ),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeColor: Colors.cyan.shade400,
          activeTrackColor: Colors.cyan.withOpacity(0.5),
        ),
      ],
    );
  }

  Widget _buildInfoTile({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(icon, color: Colors.cyan.shade400, size: 24),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 16,
              color: Colors.white,
            ),
          ),
        ),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 16,
            color: Colors.white70,
          ),
        ),
      ],
    );
  }
}
