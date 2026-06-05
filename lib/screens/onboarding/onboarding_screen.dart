import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/settings_service.dart';
import '../../services/app_store.dart';
import '../../core/constants.dart';

/// Экран первого запуска. Запрашивает имя и код подтверждения.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _nameCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  bool _obscure = true;

  @override
  void initState() {
    super.initState();
    final store = context.read<AppStore>();
    if (store.userName != null && store.userName!.isNotEmpty) {
      _nameCtrl.text = store.userName!;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _nameCtrl.text.trim();
    final code = _codeCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Введите имя пользователя')),
      );
      return;
    }
    if (code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Введите код подтверждения')),
      );
      return;
    }
    final settings = context.read<SettingsService>();
    final store = context.read<AppStore>();
    await store.setUserData(name, code);
    await store.setAuthToken(code);
    await settings.completeOnboarding(name, code);
    // После notifyListeners CompanionApp перестроится и покажет MainShell
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.auto_awesome, size: 72, color: Colors.indigo.shade400),
              const SizedBox(height: 16),
              Text(AppConstants.appName,
                  style: theme.textTheme.headlineMedium
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text('Личное рабочее пространство',
                  style: theme.textTheme.bodyLarge
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              const SizedBox(height: 32),
              TextField(
                controller: _nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Имя пользователя',
                  hintText: 'Введите ваше имя',
                  prefixIcon: Icon(Icons.person),
                  border: OutlineInputBorder(),
                ),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _codeCtrl,
                obscureText: _obscure,
                decoration: InputDecoration(
                  labelText: 'Код подтверждения',
                  hintText: 'Введите код',
                  prefixIcon: const Icon(Icons.lock),
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(_obscure
                        ? Icons.visibility_off
                        : Icons.visibility),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton.icon(
                  onPressed: _submit,
                  icon: const Icon(Icons.arrow_forward),
                  label: const Text('Продолжить'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
