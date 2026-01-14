import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:package_info_plus/package_info_plus.dart';

class HelpSupportScreen extends StatefulWidget {
  const HelpSupportScreen({Key? key}) : super(key: key);

  @override
  State<HelpSupportScreen> createState() => _HelpSupportScreenState();
}

class _HelpSupportScreenState extends State<HelpSupportScreen> {
  String _appVersion = '';

  @override
  void initState() {
    super.initState();
    _loadAppVersion();
  }

  Future<void> _loadAppVersion() async {
    final packageInfo = await PackageInfo.fromPlatform();
    setState(() {
      _appVersion = '${packageInfo.version}+${packageInfo.buildNumber}';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: CustomScrollView(
        slivers: [
          // Modern App Bar
          SliverAppBar(
            expandedHeight: 200,
            floating: false,
            pinned: true,
            backgroundColor: Colors.green,
            flexibleSpace: FlexibleSpaceBar(
              title: const Text(
                'Trợ giúp & Hỗ trợ',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  shadows: [
                    Shadow(
                      color: Colors.black26,
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
              ),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.green.shade400,
                      Colors.green.shade700,
                    ],
                  ),
                ),
                child: Stack(
                  children: [
                    Positioned(
                      right: -50,
                      top: -50,
                      child: Container(
                        width: 200,
                        height: 200,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.1),
                        ),
                      ),
                    ),
                    Positioned(
                      left: -30,
                      bottom: -30,
                      child: Container(
                        width: 150,
                        height: 150,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.1),
                        ),
                      ),
                    ),
                    Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(height: 40),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.support_agent,
                              size: 48,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Content
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Quick Actions Grid
                  _buildQuickActions(),
                  const SizedBox(height: 20),

                  // Main Sections
                  _buildModernSection(
                    icon: Icons.menu_book,
                    title: 'Hướng dẫn sử dụng',
                    subtitle: '6 hướng dẫn chi tiết',
                    color: Colors.blue,
                    onTap: () => _showGuidesBottomSheet(),
                  ),
                  const SizedBox(height: 12),

                  _buildModernSection(
                    icon: Icons.quiz,
                    title: 'Câu hỏi thường gặp',
                    subtitle: 'Giải đáp thắc mắc',
                    color: Colors.orange,
                    onTap: () => _showFaqBottomSheet(),
                  ),
                  const SizedBox(height: 12),

                  _buildModernSection(
                    icon: Icons.security,
                    title: 'Bảo mật & Quyền riêng tư',
                    subtitle: 'Chính sách bảo mật',
                    color: Colors.teal,
                    onTap: () => _showSecurityBottomSheet(),
                  ),
                  const SizedBox(height: 12),

                  _buildModernSection(
                    icon: Icons.contact_support,
                    title: 'Liên hệ hỗ trợ',
                    subtitle: 'Email, Telegram, Hotline',
                    color: Colors.purple,
                    onTap: () => _showContactBottomSheet(),
                  ),
                  const SizedBox(height: 20),

                  // App Info Card
                  _buildAppInfoCard(),
                  const SizedBox(height: 20),

                  // Footer
                  Text(
                    'Chat App v$_appVersion',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '© 2026 Chat App. All rights reserved.',
                    style: TextStyle(
                      color: Colors.grey[500],
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Container(
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          Expanded(
            child: _buildQuickActionCard(
              icon: Icons.bug_report,
              label: 'Báo lỗi',
              color: Colors.red,
              onTap: () => _showReportBugDialog(),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildQuickActionCard(
              icon: Icons.star,
              label: 'Đánh giá',
              color: Colors.amber,
              onTap: () => _showRateDialog(),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildQuickActionCard(
              icon: Icons.info,
              label: 'Về app',
              color: Colors.indigo,
              onTap: () => _showAboutDialog(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionCard({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.grey[800],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModernSection({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.grey[400], size: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildAppInfoCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.indigo.shade400, Colors.indigo.shade700],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.indigo.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.info_outline,
              size: 40,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Thông tin ứng dụng',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Phiên bản: $_appVersion',
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildInfoButton(
                icon: Icons.description,
                label: 'Điều khoản',
                onTap: () => _showTermsOfService(),
              ),
              _buildInfoButton(
                icon: Icons.privacy_tip,
                label: 'Bảo mật',
                onTap: () => _showPrivacyPolicy(),
              ),
              _buildInfoButton(
                icon: Icons.code,
                label: 'License',
                onTap: () {
                  showLicensePage(
                    context: context,
                    applicationName: 'Chat App',
                    applicationVersion: _appVersion,
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, color: Colors.white, size: 24),
            const SizedBox(height: 6),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Bottom Sheets
  void _showGuidesBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Handle
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Title
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.menu_book, color: Colors.blue),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Hướng dẫn sử dụng',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              // List
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  children: [
                    _buildListTile(
                      icon: Icons.message,
                      title: 'Cách gửi tin nhắn',
                      subtitle: 'Text, voice, ảnh, file',
                      onTap: () => _showGuideDetail('Cách gửi tin nhắn'),
                    ),
                    _buildListTile(
                      icon: Icons.group_add,
                      title: 'Cách tạo nhóm chat',
                      subtitle: 'Tạo và quản lý nhóm',
                      onTap: () => _showGuideDetail('Cách tạo nhóm chat'),
                    ),
                    _buildListTile(
                      icon: Icons.video_call,
                      title: 'Cách gọi video call',
                      subtitle: 'Thực hiện cuộc gọi video',
                      onTap: () => _showGuideDetail('Cách gọi video call'),
                    ),
                    _buildListTile(
                      icon: Icons.lock,
                      title: 'Mã hóa end-to-end',
                      subtitle: 'Bảo mật tin nhắn',
                      onTap: () => _showGuideDetail('Mã hóa end-to-end'),
                    ),
                    _buildListTile(
                      icon: Icons.security,
                      title: 'Chat riêng tư',
                      subtitle: 'Thiết lập mật khẩu',
                      onTap: () => _showGuideDetail('Chat riêng tư'),
                    ),
                    _buildListTile(
                      icon: Icons.auto_delete,
                      title: 'Tự động xóa tin nhắn',
                      subtitle: 'Cài đặt thời gian xóa',
                      onTap: () => _showGuideDetail('Tự động xóa tin nhắn'),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showFaqBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.quiz, color: Colors.orange),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Câu hỏi thường gặp',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  children: [
                    _buildListTile(
                      icon: Icons.person_add,
                      title: 'Làm sao để thêm bạn bè?',
                      subtitle: 'Tìm kiếm và kết nối',
                      onTap: () => _showFaqDetail('Làm sao để thêm bạn bè?'),
                    ),
                    _buildListTile(
                      icon: Icons.delete,
                      title: 'Làm sao để xóa tin nhắn?',
                      subtitle: 'Xóa tin nhắn đã gửi',
                      onTap: () => _showFaqDetail('Làm sao để xóa tin nhắn?'),
                    ),
                    _buildListTile(
                      icon: Icons.account_circle,
                      title: 'Làm sao để thay đổi avatar?',
                      subtitle: 'Cập nhật ảnh đại diện',
                      onTap: () => _showFaqDetail('Làm sao để thay đổi avatar?'),
                    ),
                    _buildListTile(
                      icon: Icons.notifications,
                      title: 'Làm sao để bật/tắt thông báo?',
                      subtitle: 'Quản lý thông báo',
                      onTap: () => _showFaqDetail('Làm sao để bật/tắt thông báo?'),
                    ),
                    _buildListTile(
                      icon: Icons.error,
                      title: 'Tại sao tin nhắn không gửi được?',
                      subtitle: 'Xử lý lỗi gửi tin nhắn',
                      onTap: () => _showFaqDetail('Tại sao tin nhắn không gửi được?'),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSecurityBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.teal.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.security, color: Colors.teal),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Bảo mật & Quyền riêng tư',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  children: [
                    _buildListTile(
                      icon: Icons.policy,
                      title: 'Chính sách bảo mật',
                      subtitle: 'Cách chúng tôi bảo vệ dữ liệu',
                      onTap: () => _showSecurityDetail('Chính sách bảo mật'),
                    ),
                    _buildListTile(
                      icon: Icons.perm_device_info,
                      title: 'Quyền truy cập',
                      subtitle: 'Camera, micro, storage',
                      onTap: () => _showSecurityDetail('Quyền truy cập'),
                    ),
                    _buildListTile(
                      icon: Icons.enhanced_encryption,
                      title: 'Mã hóa end-to-end',
                      subtitle: 'Công nghệ bảo mật',
                      onTap: () => _showSecurityDetail('Mã hóa end-to-end'),
                    ),
                    _buildListTile(
                      icon: Icons.report,
                      title: 'Báo cáo vi phạm',
                      subtitle: 'Báo cáo người dùng xấu',
                      onTap: () => _showSecurityDetail('Báo cáo vi phạm'),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showContactBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(bottom: 20),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.purple.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.contact_support, color: Colors.purple),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Liên hệ hỗ trợ',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildContactCard(
              icon: Icons.email,
              title: 'Email',
              value: 'blequyet1906@gmail.com',
              color: Colors.red,
              onTap: () => _launchUrl('mailto:blequyet1906@gmail.com'),
            ),
            const SizedBox(height: 12),
            _buildContactCard(
              icon: Icons.telegram,
              title: 'Telegram',
              value: '@lequyet',
              color: Colors.blue,
              onTap: () => _launchUrl('https://t.me/lequyet'),
            ),
            const SizedBox(height: 12),
            _buildContactCard(
              icon: Icons.phone,
              title: 'Hotline (24/7)',
              value: '0988770211',
              color: Colors.green,
              onTap: () => _launchUrl('tel:0988770211'),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildListTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.grey[700], size: 24),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.grey[400], size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildContactCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, color: color, size: 16),
          ],
        ),
      ),
    );
  }

  // Dialogs (keeping original content logic)
  void _showGuideDetail(String title) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.book, color: Colors.blue),
            const SizedBox(width: 12),
            Expanded(child: Text(title, style: const TextStyle(fontSize: 18))),
          ],
        ),
        content: SingleChildScrollView(
          child: _getGuideContent(title),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
  }

  Widget _getGuideContent(String title) {
    // Keep original content from previous version
    switch (title) {
      case 'Cách gửi tin nhắn':
        return const Text('1. Mở cuộc trò chuyện\n2. Nhập tin nhắn vào ô chat\n3. Nhấn biểu tượng để gửi:\n   • 📷 Camera: Chụp ảnh\n   • 🖼️ Gallery: Chọn ảnh\n   • 📁 File: Gửi file\n   • 🎤 Voice: Ghi âm\n4. Nhấn nút gửi');
      case 'Cách tạo nhóm chat':
        return const Text('1. Vào tab "Nhóm"\n2. Nhấn nút "+"\n3. Chọn "Tạo nhóm mới"\n4. Nhập tên nhóm\n5. Chọn thành viên\n6. Nhấn "Tạo nhóm"');
      case 'Cách gọi video call':
        return const Text('1. Mở cuộc trò chuyện\n2. Nhấn icon video call\n3. Chờ chấp nhận\n4. Sử dụng:\n   • 🎤 Tắt/bật micro\n   • 📷 Tắt/bật camera\n   • 🔄 Đổi camera\n   • ❌ Kết thúc');
      case 'Mã hóa end-to-end':
        return const Text('Mã hóa end-to-end bảo vệ tin nhắn:\n\n• Chỉ bạn và người nhận đọc được\n• Không ai khác truy cập (kể cả chúng tôi)\n• Mã hóa trên thiết bị\n• Giải mã chỉ trên thiết bị nhận\n\n🔒 hiển thị khi bật');
      case 'Chat riêng tư':
        return const Text('1. Vào Cài đặt → Chat riêng tư\n2. Bật khóa\n3. Thiết lập mật khẩu (≥4 ký tự)\n4. Chat yêu cầu mật khẩu\n\nLưu ý: Quên mật khẩu = mất quyền truy cập!');
      case 'Tự động xóa tin nhắn':
        return const Text('1. Mở nhóm chat\n2. Menu → Thông tin nhóm\n3. Chọn "Tự động xóa"\n4. Chọn thời gian:\n   • 1 giờ\n   • 24 giờ\n   • 7 ngày\n   • 30 ngày');
      default:
        return Text('Chi tiết: $title');
    }
  }

  void _showFaqDetail(String title) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.quiz, color: Colors.orange),
            const SizedBox(width: 12),
            Expanded(child: Text(title, style: const TextStyle(fontSize: 18))),
          ],
        ),
        content: SingleChildScrollView(child: _getFaqContent(title)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
  }

  Widget _getFaqContent(String title) {
    switch (title) {
      case 'Làm sao để thêm bạn bè?':
        return const Text('1. Tìm kiếm trong tab "Trò chuyện"\n2. Nhấn tên người dùng\n3. Gửi tin nhắn đầu tiên\n\nTự động kết nối với Firebase users');
      case 'Làm sao để xóa tin nhắn?':
        return const Text('1. Nhấn giữ tin nhắn\n2. Chọn "Xóa tin nhắn"\n3. Xác nhận\n\nLưu ý: Không thể khôi phục!');
      case 'Làm sao để thay đổi avatar?':
        return const Text('1. Vào Cài đặt\n2. Nhấn avatar hiện tại\n3. Chọn:\n   • Chụp ảnh mới\n   • Chọn từ thư viện\n4. Cắt và xác nhận');
      case 'Làm sao để bật/tắt thông báo?':
        return const Text('1. Vào Cài đặt → Thông báo\n2. Bật/tắt:\n   • Thông báo tin nhắn\n   • Âm thanh\n   • Rung\n   • Preview\n\nTắt riêng cho từng chat');
      case 'Tại sao tin nhắn không gửi được?':
        return const Text('Nguyên nhân:\n\n1. Không có internet\n   → Kiểm tra WiFi/4G\n\n2. File quá lớn (>10MB)\n   → Nén file\n\n3. Không có quyền\n   → Cấp quyền trong Settings\n\n4. Lỗi server\n   → Thử lại');
      default:
        return Text('Câu trả lời: $title');
    }
  }

  void _showSecurityDetail(String title) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.security, color: Colors.teal),
            const SizedBox(width: 12),
            Expanded(child: Text(title, style: const TextStyle(fontSize: 18))),
          ],
        ),
        content: SingleChildScrollView(child: _getSecurityContent(title)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
  }

  Widget _getSecurityContent(String title) {
    switch (title) {
      case 'Chính sách bảo mật':
        return const Text('1. Thu thập:\n   • Email, tên, avatar\n   • Tin nhắn và file\n   • Thông tin cuộc gọi\n\n2. Sử dụng:\n   • Cung cấp dịch vụ\n   • Cải thiện UX\n   • Không bán cho bên thứ 3\n\n3. Bảo mật:\n   • Mã hóa E2E\n   • Firebase secure\n   • GDPR compliant');
      case 'Quyền truy cập':
        return const Text('📷 Camera:\n• Chụp ảnh\n• Video call\n\n🎤 Microphone:\n• Voice message\n• Video call\n\n📁 Storage:\n• Lưu và gửi file\n\n📍 Location:\n• Chia sẻ vị trí\n\nQuản lý: Settings → Apps');
      case 'Mã hóa end-to-end':
        return const Text('🔒 Hoạt động:\n1. Mã hóa trên thiết bị\n2. Chỉ người nhận có key\n3. Server chỉ chuyển tiếp\n4. Không ai đọc được\n\n🛡️ Công nghệ:\n• AES-256\n• RSA key exchange\n• Perfect Forward Secrecy');
      case 'Báo cáo vi phạm':
        return const Text('1. Mở chat\n2. Menu (⋮) → Báo cáo\n3. Chọn lý do:\n   • Spam\n   • Lừa đảo\n   • Quấy rối\n   • Nội dung xấu\n4. Mô tả\n5. Gửi\n\nXử lý trong 24-48h');
      default:
        return Text('Chi tiết: $title');
    }
  }

  void _showReportBugDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.bug_report, color: Colors.red),
            SizedBox(width: 12),
            Text('Báo cáo lỗi'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Mô tả chi tiết lỗi:'),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              style: const TextStyle(
                color: Colors.black87,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 5,
              decoration: InputDecoration(
                hintText: 'Ví dụ: Không thể gửi ảnh...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.grey[50],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('✅ Báo cáo đã được gửi!'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Gửi'),
          ),
        ],
      ),
    );
  }

  void _showRateDialog() {
    int rating = 0;
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.star, color: Colors.amber),
              SizedBox(width: 8),
              Flexible(
                child: Text(
                  'Đánh giá ứng dụng',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Bạn thích app của chúng tôi?',
                style: TextStyle(fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.maxFinite,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: List.generate(5, (index) {
                    return IconButton(
                      padding: EdgeInsets.all(4),
                      constraints: BoxConstraints(),
                      onPressed: () => setState(() => rating = index + 1),
                      icon: Icon(
                        index < rating ? Icons.star : Icons.star_border,
                        color: Colors.amber,
                        size: 36,
                      ),
                    );
                  }),
                ),
              ),
              if (rating > 0) ...[
                const SizedBox(height: 12),
                Text(
                  rating >= 4 ? '🎉 Tuyệt vời!' : '😊 Cảm ơn feedback!',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Để sau'),
            ),
            ElevatedButton(
              onPressed: rating > 0
                  ? () {
                      Navigator.pop(context);
                      if (rating >= 4) {
                        _launchUrl('https://play.google.com/store');
                      }
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(rating >= 4 ? '🌟 Cảm ơn đánh giá 5 sao!' : '💚 Chúng tôi sẽ cải thiện!'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                disabledBackgroundColor: Colors.grey[300],
              ),
              child: const Text('Đánh giá'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.info, color: Colors.indigo),
            SizedBox(width: 12),
            Text('Về ứng dụng'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.indigo.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.chat, size: 48, color: Colors.indigo),
            ),
            const SizedBox(height: 16),
            const Text(
              'Chat App',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Version $_appVersion',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Ứng dụng chat bảo mật với mã hóa end-to-end, video call, và nhiều tính năng hiện đại.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey[700],
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '© 2026 Chat App\nAll rights reserved',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 11,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
  }

  void _showTermsOfService() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Điều khoản sử dụng'),
        content: const SingleChildScrollView(
          child: Text(
            'ĐIỀU KHOẢN SỬ DỤNG\n\n'
            '1. Chấp nhận điều khoản\n'
            'Sử dụng app = đồng ý điều khoản\n\n'
            '2. Sử dụng hợp pháp\n'
            'Cam kết không vi phạm pháp luật\n\n'
            '3. Nội dung người dùng\n'
            'Chịu trách nhiệm nội dung chia sẻ\n\n'
            '4. Quyền riêng tư\n'
            'Bảo vệ theo chính sách\n\n'
            '5. Thay đổi\n'
            'Có quyền cập nhật điều khoản\n\n'
            'Cập nhật: 14/01/2026',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
  }

  void _showPrivacyPolicy() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Chính sách quyền riêng tư'),
        content: const SingleChildScrollView(
          child: Text(
            'CHÍNH SÁCH QUYỀN RIÊNG TƯ\n\n'
            '1. Thu thập:\n'
            '• Email, tên, avatar\n'
            '• Nội dung tin nhắn\n'
            '• Dữ liệu sử dụng\n\n'
            '2. Sử dụng:\n'
            '• Cung cấp dịch vụ\n'
            '• Cải thiện UX\n'
            '• Hỗ trợ khách hàng\n\n'
            '3. Chia sẻ:\n'
            '• KHÔNG bán dữ liệu\n'
            '• Chỉ khi có yêu cầu pháp lý\n\n'
            '4. Bảo mật:\n'
            '• Mã hóa E2E\n'
            '• Firebase secure\n'
            '• GDPR compliant\n\n'
            'Liên hệ: privacy@chatapp.com\n'
            'Cập nhật: 14/01/2026',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
  }

  Future<void> _launchUrl(String url) async {
    final Uri uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không thể mở: $url')),
        );
      }
    }
  }
}
