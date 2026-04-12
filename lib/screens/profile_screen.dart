import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/price_service.dart';
import '../providers/price_alert_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/matte_frosted_glass_card.dart';
import '../providers/language_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'auth_wrapper.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final PriceService _service = PriceService();
  bool _notificationsEnabled = true;

  String _locationName = 'Fetching location...';
  bool _isLoadingLocation = true;
  bool _locationPermissionDenied = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _initLocation();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;
      });
    }
  }

  Future<void> _initLocation() async {
    if (!mounted) return;
    setState(() {
      _isLoadingLocation = true;
      _locationPermissionDenied = false;
    });

    try {
      // Permission check using permission_handler as requested
      var status = await Permission.location.status;
      if (!status.isGranted) {
        status = await Permission.location.request();
      }

      if (status.isPermanentlyDenied || status.isRestricted || status.isDenied) {
        if (mounted) {
          setState(() {
            _locationName = 'Location permission denied';
            _isLoadingLocation = false;
            _locationPermissionDenied = true;
          });
        }
        return;
      }

      // Get Position
      final Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.low,
      );

      // Reverse Geocode
      final List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (mounted) {
        if (placemarks.isNotEmpty) {
          final pm = placemarks.first;
          setState(() {
            _locationName = '${pm.locality ?? 'Unknown'}, ${pm.administrativeArea ?? pm.country ?? ''}';
            _isLoadingLocation = false;
          });
        } else {
          setState(() {
            _locationName = 'Location not available';
            _isLoadingLocation = false;
          });
        }
      }
    } catch (e) {
      debugPrint('Error getting location: $e');
      if (mounted) {
        setState(() {
          _locationName = 'Location not available';
          _isLoadingLocation = false;
        });
      }
    }
  }

  User? get _user => Supabase.instance.client.auth.currentUser;
  bool get _isLoggedIn => _user != null;

  String get _displayName {
    if (!_isLoggedIn) return 'Guest';
    final metadata = _user!.userMetadata;
    return metadata?['full_name'] ?? metadata?['name'] ?? 'KoyamRate User';
  }

  // Static Tamil fallback for "Guest"
  String get _displayNameTamil => _isLoggedIn ? '' : 'விருந்தினர்';

  String toTitleCase(String name) {
    return name.split(' ')
      .map((w) => w.isEmpty ? w :
        w[0].toUpperCase() + w.substring(1).toLowerCase())
      .join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final isTamil = ref.watch(languageProvider);
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: SafeArea(
        child: _isLoggedIn ? _buildProfileContent(isTamil) : _buildLoginPrompt(isTamil),
      ),
    );
  }

  Widget _buildLoginPrompt(bool isTamil) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 20,
                    spreadRadius: 5,
                  )
                ],
              ),
              child: const Icon(Icons.account_circle_outlined, size: 80, color: AppColors.primary),
            ),
            const SizedBox(height: 32),
            Text(
              isTamil ? 'உள்நுழையவும்' : 'Sign in to KoyamRate',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 12),
            Text(
              isTamil ? 'உங்களுக்குப் பிடித்தவைகளைச் சேமிக்கவும்.' : 'Save your favorites and get personalized price alerts.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  // Exit guest mode and return to Login Screen
                  ref.read(guestModeProvider.notifier).setGuestMode(false);
                },
                icon: const Text(
                  'G',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF4285F4),
                  ),
                ),
                label: Text(isTamil ? 'கூகுள் மூலம் தொடரவும்' : 'Sign in with Google'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.textPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: Colors.grey.shade200),
                  ),
                  elevation: 2,
                  shadowColor: Colors.black.withValues(alpha: 0.1),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showDeleteAccountDialog(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Account?'),
        content: const Text(
          'This will permanently delete your profile, favorites, and price alerts. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete Permanently'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        // Show loading
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(child: CircularProgressIndicator()),
        );

        // Call the RPC to delete account from auth.users (cascades to public data)
        await Supabase.instance.client.rpc('delete_user_account');
        
        // Sign out just in case the RPC didn't trigger local session clear
        await Supabase.instance.client.auth.signOut();

        if (mounted) {
          Navigator.pop(context); // Close loading
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Account deleted successfully')),
          );
        }
      } catch (e) {
        if (mounted) {
          Navigator.pop(context); // Close loading
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting account: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  Widget _buildProfileContent(bool isTamil) {
    return RefreshIndicator(
      onRefresh: () async {
        await _initLocation();
        await _loadSettings();
      },
      color: AppColors.green,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          children: [
            const SizedBox(height: 16),
            // Header Title
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF3E0),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.person_outline, color: AppColors.primary, size: 24),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Profile / நான்',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                ),
              ],
            ),

            const SizedBox(height: 40),

            // Avatar
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 4),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  )
                ],
                color: Colors.grey.shade100,
              ),
              child: ClipOval(
                child: _buildAvatarImage(),
              ),
            ),

            const SizedBox(height: 24),

            // Dynamic Name
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  if (_displayNameTamil.isNotEmpty)
                    Text(
                      _displayNameTamil,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: AppColors.textPrimary, letterSpacing: -0.5),
                    ),
                  Text(
                    toTitleCase(_displayName),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: _displayNameTamil.isEmpty ? 28 : 16, 
                      fontWeight: _displayNameTamil.isEmpty ? FontWeight.w900 : FontWeight.w500, 
                      color: _displayNameTamil.isEmpty ? AppColors.textPrimary : Colors.grey, 
                      letterSpacing: 1.0, 
                      height: 1.2
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Location Badge
            _buildLocationBadge(),

            const SizedBox(height: 40),

            // Settings List
            _buildMenuItem(
              icon: Icons.language,
              iconColor: Colors.indigo,
              label: isTamil ? 'மொழி' : 'Language',
              trailing: _buildLanguageToggle(isTamil),
            ),
            const SizedBox(height: 12),
            _buildMenuItem(
              icon: Icons.notifications_none_rounded,
              iconColor: Colors.blue,
              label: isTamil ? 'அறிவிப்புகள்' : 'Notifications',
              onTap: () {
                debugPrint('🔔 User manually checking for notifications...');
                ref.read(priceAlertProvider.notifier).checkPendingNotifications();
              },
              trailing: Switch(
                value: _notificationsEnabled,
                onChanged: (val) async {
                  setState(() => _notificationsEnabled = val);
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setBool('notifications_enabled', val);
                },
                activeTrackColor: AppColors.green.withValues(alpha: 0.3),
                activeThumbColor: AppColors.green,
              ),
            ),
            const SizedBox(height: 12),
            _buildMenuItem(
              icon: Icons.info_outline_rounded,
              iconColor: Colors.orange,
              label: isTamil ? 'தகவல் ஆதாரம்' : 'Data Source',
              subtitle: isTamil ? 'அதிகாரப்பூர்வ MMC KWMC தளம் மூலம்' : 'Powered by MMC KWMC Official Portal',
              onTap: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Data Source / தகவல் ஆதாரம்', style: TextStyle(fontWeight: FontWeight.bold)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    content: const SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'English:',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.primary),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Prices sourced from official Tamil Nadu Government (KWMC). For information only. Not responsible for any loss.',
                            style: TextStyle(fontSize: 14, height: 1.4),
                          ),
                          SizedBox(height: 20),
                          Text(
                            'தமிழ்:',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.primary),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'விலைகள் அரசு அதிகாரப்பூர்வ KWMC தளத்திலிருந்து எடுக்கப்பட்டவை. தகவல் நோக்கத்திற்கு மட்டும். எந்த நஷ்டத்திற்கும் பொறுப்பல்ல.',
                            style: TextStyle(fontSize: 14, height: 1.4),
                          ),
                        ],
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Close / மூடு', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            _buildMenuItem(
              icon: Icons.privacy_tip_outlined,
              iconColor: Colors.teal,
              label: isTamil ? 'தனியுரிமைக் கொள்கை' : 'Privacy Policy',
              onTap: () async {
                final uri = Uri.parse(
                  'https://sites.google.com/view/koyamrateprivacypolicy'
                );
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                } else {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Could not open Privacy Policy')),
                    );
                  }
                }
              },
            ),
            const SizedBox(height: 32),

            // Logout
            SizedBox(
              width: double.infinity,
              child: TextButton.icon(
                onPressed: () async {
                  await Supabase.instance.client.auth.signOut();
                  // Re-initialize location name to "Loading..." for next visitor
                  if (mounted) {
                    setState(() {
                      _locationName = 'Loading...';
                    });
                  }
                },
                icon: const Icon(Icons.logout, color: Colors.redAccent),
                label: Text(isTamil ? 'வெளியேறு' : 'Logout', style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w700, fontSize: 16)),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: Colors.redAccent.withValues(alpha: 0.2)),
                  ),
                  backgroundColor: Colors.redAccent.withValues(alpha: 0.05),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Delete Account (Privacy Compliance)
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => _showDeleteAccountDialog(context),
                child: Text(
                  isTamil ? 'கணக்கை நீக்கு' : 'Delete Account & Data',
                  style: TextStyle(
                    color: Colors.red.withValues(alpha: 0.6),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 40),

            // Footer
            Column(
              children: [
                Text(
                  'v1.0.0+1',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey.shade400),
                ),
                const SizedBox(height: 4),
                Text(
                  'Made with ❤️ in Chennai',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
                ),
              ],
            ),
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatarImage() {
    final avatarUrl = _user?.userMetadata?['avatar_url'] as String?;
    if (avatarUrl != null && Uri.tryParse(avatarUrl)?.hasScheme == true) {
      return Image.network(
        avatarUrl,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          debugPrint('⚠️ Failed to load avatar: $error');
          return const Icon(Icons.person, size: 70, color: Colors.grey);
        },
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return const Center(
            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
          );
        },
      );
    }
    return const Icon(Icons.person, size: 70, color: Colors.grey);
  }

  Widget _buildLocationBadge() {
    if (_locationPermissionDenied) {
      return TextButton.icon(
        onPressed: _initLocation,
        icon: const Icon(Icons.location_off, size: 16, color: Colors.redAccent),
        label: const Text('Enable Location', style: TextStyle(fontSize: 13, color: Colors.redAccent, fontWeight: FontWeight.bold)),
        style: TextButton.styleFrom(
          backgroundColor: Colors.redAccent.withValues(alpha: 0.1),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          padding: const EdgeInsets.symmetric(horizontal: 16),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_isLoadingLocation)
            const SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF2563EB)),
            )
          else
            const Icon(Icons.location_on, size: 14, color: Color(0xFF2563EB)),
          const SizedBox(width: 8),
          Text(
            _locationName,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF2563EB)),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required Color iconColor,
    required String label,
    String? subtitle,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: MatteFrostedGlassCard(
        backgroundColor: Colors.white.withValues(alpha: 0.7),
        borderRadius: 20,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        enableShadow: false,
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, size: 22, color: iconColor),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade500, fontWeight: FontWeight.w500),
                    ),
                ],
              ),
            ),
            if (trailing != null) trailing,
          ],
        ),
      ),
    );
  }

  Widget _buildLanguageToggle(bool isTamil) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildToggleOption('ENG', !isTamil),
          _buildToggleOption('TAM', isTamil),
        ],
      ),
    );
  }

  Widget _buildToggleOption(String label, bool isSelected) {
    return GestureDetector(
      onTap: () {
        final isTamilSelect = label == 'TAM';
        ref.read(languageProvider.notifier).setLanguage(isTamilSelect);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: isSelected
              ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 2))]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: isSelected ? AppColors.green : Colors.grey.shade500,
          ),
        ),
      ),
    );
  }
}
