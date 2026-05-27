import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'beranda_screen.dart';
import 'lapor_screen.dart';
import 'profil_screen.dart';
import 'tugas_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  String _userRole = 'warga';
  bool _isLoadingRole = true;
  bool _showBottomBar = true; // State untuk animasi sembunyi/muncul

  @override
  void initState() {
    super.initState();
    _loadUserRole();
  }

  Future<void> _loadUserRole() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _userRole =
          prefs.getString('user_role') ?? prefs.getString('role') ?? 'warga';
      _isLoadingRole = false;
    });
  }

  void _onScrollDirectionChanged(bool isVisible) {
    if (_showBottomBar != isVisible) {
      setState(() => _showBottomBar = isVisible);
    }
  }

  // --- LOGIKA DINAMIS HALAMAN ---
  List<Widget> get _widgetOptions {
    if (_userRole == 'petugas' ||
        _userRole == 'admin' ||
        _userRole == 'dinas') {
      return [
        const BerandaScreen(),
        const TugasScreen(),
        ProfilScreen(onScrollDirectionChanged: _onScrollDirectionChanged),
      ];
    }
    return [
      const BerandaScreen(),
      const LaporScreen(),
      ProfilScreen(onScrollDirectionChanged: _onScrollDirectionChanged),
    ];
  }

  // --- LOGIKA DINAMIS MENU NAVIGASI BAWAH ---
  List<BottomNavigationBarItem> get _navItems {
    if (_userRole == 'petugas' ||
        _userRole == 'admin' ||
        _userRole == 'dinas') {
      return const [
        BottomNavigationBarItem(
          icon: Padding(
            padding: EdgeInsets.only(bottom: 4),
            child: Icon(Icons.home_outlined),
          ),
          activeIcon: Padding(
            padding: EdgeInsets.only(bottom: 4),
            child: Icon(Icons.home_rounded),
          ),
          label: 'Beranda',
        ),
        BottomNavigationBarItem(
          icon: Padding(
            padding: EdgeInsets.only(bottom: 4),
            child: Icon(Icons.assignment_outlined),
          ),
          activeIcon: Padding(
            padding: EdgeInsets.only(bottom: 4),
            child: Icon(Icons.assignment),
          ),
          label: 'Tugas',
        ),
        BottomNavigationBarItem(
          icon: Padding(
            padding: EdgeInsets.only(bottom: 4),
            child: Icon(Icons.person_outline),
          ),
          activeIcon: Padding(
            padding: EdgeInsets.only(bottom: 4),
            child: Icon(Icons.person_rounded),
          ),
          label: 'Profil',
        ),
      ];
    }
    return const [
      BottomNavigationBarItem(
        icon: Padding(
          padding: EdgeInsets.only(bottom: 4),
          child: Icon(Icons.home_outlined),
        ),
        activeIcon: Padding(
          padding: EdgeInsets.only(bottom: 4),
          child: Icon(Icons.home_rounded),
        ),
        label: 'Beranda',
      ),
      BottomNavigationBarItem(
        icon: Padding(
          padding: EdgeInsets.only(bottom: 4),
          child: Icon(Icons.add_a_photo_outlined),
        ),
        activeIcon: Padding(
          padding: EdgeInsets.only(bottom: 4),
          child: Icon(Icons.add_a_photo_rounded),
        ),
        label: 'Lapor',
      ),
      BottomNavigationBarItem(
        icon: Padding(
          padding: EdgeInsets.only(bottom: 4),
          child: Icon(Icons.person_outline),
        ),
        activeIcon: Padding(
          padding: EdgeInsets.only(bottom: 4),
          child: Icon(Icons.person_rounded),
        ),
        label: 'Profil',
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingRole) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          'TCC Lapor',
          style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: 0.5),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.blue.shade900,
        elevation: 0,
        centerTitle: true,
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        transitionBuilder: (Widget child, Animation<double> animation) {
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.0, 0.05),
                end: Offset.zero,
              ).animate(animation),
              child: child,
            ),
          );
        },
        child: _widgetOptions[_selectedIndex],
      ),
      extendBody: true, // Wajib agar list bisa di-scroll menembus area bawah
      bottomNavigationBar: AnimatedSlide(
        duration: const Duration(milliseconds: 300),
        offset: _showBottomBar
            ? Offset.zero
            : const Offset(0, 2), // Geser bar ke bawah layar jika false
        child: Container(
          margin: const EdgeInsets.only(left: 24, right: 24, bottom: 24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 20,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(30),
            child: BottomNavigationBar(
              backgroundColor: Colors.white,
              elevation: 0,
              type: BottomNavigationBarType.fixed,
              showSelectedLabels: true,
              showUnselectedLabels: false,
              selectedItemColor: Colors.blue.shade700,
              unselectedItemColor: Colors.grey.shade400,
              selectedLabelStyle: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
              currentIndex: _selectedIndex,
              onTap: (index) => setState(() => _selectedIndex = index),
              items: _navItems,
            ),
          ),
        ),
      ),
    );
  }
}
