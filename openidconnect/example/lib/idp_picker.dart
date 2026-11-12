import 'package:material_ui/material_ui.dart';

import 'idp_catalog.dart';
import 'idp_profile.dart';

class IdpPicker extends StatelessWidget {
  const IdpPicker({super.key});

  @override
  Widget build(BuildContext context) {
    final catalog = IdpCatalog.of(context);
    final profile = catalog.selected;
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        children: [
          Text('Identity provider', style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(profile.name, textAlign: TextAlign.center),
          Text(
            profile.discoveryUrl,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall,
          ),
          if (profile.notes != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                profile.notes!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall,
              ),
            ),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            children: [
              TextButton(
                key: const ValueKey('choose_idp'),
                onPressed: () => _choose(context),
                child: const Text('Choose IdP'),
              ),
              TextButton(
                key: const ValueKey('add_idp'),
                onPressed: () => _add(context),
                child: const Text('Add IdP'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _choose(BuildContext context) async {
    final catalog = IdpCatalog.of(context);
    final selected = await showDialog<IdpProfile>(
      context: context,
      builder: (context) {
        return SimpleDialog(
          title: const Text('Choose identity provider'),
          children: [
            for (final profile in catalog.profiles)
              SimpleDialogOption(
                onPressed: () => Navigator.of(context).pop(profile),
                child: Text(profile.name),
              ),
          ],
        );
      },
    );
    if (selected != null) {
      catalog.select(selected);
    }
  }

  Future<void> _add(BuildContext context) async {
    final catalog = IdpCatalog.of(context);
    final profile = await showDialog<IdpProfile>(
      context: context,
      builder: (context) => const _AddIdpDialog(),
    );
    if (profile != null) {
      catalog.add(profile);
    }
  }
}

class _AddIdpDialog extends StatefulWidget {
  const _AddIdpDialog();

  @override
  State<_AddIdpDialog> createState() => _AddIdpDialogState();
}

class _AddIdpDialogState extends State<_AddIdpDialog> {
  final _formKey = GlobalKey<FormState>();
  String name = '';
  String discoveryUrl = '';
  String clientId = '';
  String clientSecret = '';
  String deviceClientId = '';
  String scopes = 'openid profile email offline_access';
  String usernameHint = '';
  String passwordHint = '';
  bool supportsDevice = false;
  bool supportsPassword = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add identity provider'),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  decoration: const InputDecoration(labelText: 'Name'),
                  onChanged: (value) => name = value,
                  validator: _required,
                ),
                TextFormField(
                  decoration: const InputDecoration(labelText: 'Discovery URL'),
                  keyboardType: TextInputType.url,
                  onChanged: (value) => discoveryUrl = value,
                  validator: _required,
                ),
                TextFormField(
                  decoration: const InputDecoration(labelText: 'Client ID'),
                  onChanged: (value) => clientId = value,
                  validator: _required,
                ),
                TextFormField(
                  decoration: const InputDecoration(
                    labelText: 'Client secret (optional)',
                  ),
                  onChanged: (value) => clientSecret = value,
                ),
                TextFormField(
                  decoration: const InputDecoration(
                    labelText: 'Device client ID (optional)',
                  ),
                  onChanged: (value) => deviceClientId = value,
                ),
                TextFormField(
                  decoration: const InputDecoration(labelText: 'Scopes'),
                  initialValue: scopes,
                  onChanged: (value) => scopes = value,
                ),
                TextFormField(
                  decoration: const InputDecoration(
                    labelText: 'Username hint (optional)',
                  ),
                  onChanged: (value) => usernameHint = value,
                ),
                TextFormField(
                  decoration: const InputDecoration(
                    labelText: 'Password hint (optional)',
                  ),
                  onChanged: (value) => passwordHint = value,
                ),
                SwitchListTile.adaptive(
                  title: const Text('Device flow'),
                  value: supportsDevice,
                  onChanged: (value) => setState(() => supportsDevice = value),
                ),
                SwitchListTile.adaptive(
                  title: const Text('Password grant'),
                  value: supportsPassword,
                  onChanged: (value) =>
                      setState(() => supportsPassword = value),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            if (!_formKey.currentState!.validate()) return;
            Navigator.of(context).pop(
              IdpProfile(
                id: 'custom-${DateTime.now().millisecondsSinceEpoch}',
                name: name.trim(),
                discoveryUrl: discoveryUrl.trim(),
                clientId: clientId.trim(),
                clientSecret: _blankToNull(clientSecret),
                deviceClientId: _blankToNull(deviceClientId),
                scopes: scopes
                    .split(RegExp(r'\s+'))
                    .where((scope) => scope.isNotEmpty)
                    .toList(),
                usernameHint: _blankToNull(usernameHint),
                passwordHint: _blankToNull(passwordHint),
                supportsDevice: supportsDevice,
                supportsPassword: supportsPassword,
              ),
            );
          },
          child: const Text('Add'),
        ),
      ],
    );
  }

  String? _required(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Required';
    }
    return null;
  }

  String? _blankToNull(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}
