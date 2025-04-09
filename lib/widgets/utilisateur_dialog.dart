// part of '../main.dart';
//
// class _UtilisateurDialog extends StatefulWidget {
//   final String title;
//   final String confirmButtonText;
//   final Utilisateur? initialUser;
//
//   const _UtilisateurDialog({
//     super.key,
//     required this.title,
//     required this.confirmButtonText,
//     this.initialUser,
//   });
//
//   @override
//   State<_UtilisateurDialog> createState() => _UtilisateurDialogState();
// }
//
// class _UtilisateurDialogState extends State<_UtilisateurDialog> {
//   final _formKey = GlobalKey<FormState>();
//
//   late TextEditingController _usernameController;
//   late TextEditingController _rolesController;
//   late TextEditingController _sitesController;
//   late TextEditingController _passwordController;
//
//   @override
//   void initState() {
//     super.initState();
//     _usernameController = TextEditingController(
//       text: widget.initialUser?.login ?? '',
//     );
//     // Affichage des rôles séparés par des virgules
//     _rolesController = TextEditingController(
//       text: widget.initialUser != null
//           ? widget.initialUser!.roles.join(', ')
//           : '',
//     );
//     // Affichage des sites séparés par des virgules
//     _sitesController = TextEditingController(
//       text: widget.initialUser != null
//           ? widget.initialUser!.sites.join(', ')
//           : '',
//     );
//     _passwordController = TextEditingController();
//   }
//
//   @override
//   void dispose() {
//     _usernameController.dispose();
//     _rolesController.dispose();
//     _sitesController.dispose();
//     _passwordController.dispose();
//     super.dispose();
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     // Récupération de l'utilisateur connecté via le Provider.
//     final currentUser =
//         Provider.of<AuthProvider>(context, listen: false).currentUser;
//
//     // Déterminer si le champ password doit être affiché :
//     // - En création, toujours afficher.
//     // - En modification, si l'utilisateur connecté est super-admin ou,
//     //   s'il est admin et partage au moins un site avec l'utilisateur édité.
//     bool canEditPassword = false;
//     if (widget.initialUser == null) {
//       canEditPassword = true;
//     } else if (currentUser != null) {
//       if (currentUser.roles.contains('super-admin')) {
//         canEditPassword = true;
//       } else if (currentUser.roles.contains('admin')) {
//         // Vérifie si le user connecté partage au moins un site avec l'utilisateur édité.
//         if (widget.initialUser!.sites
//             .any((s) => currentUser.sites.contains(s))) {
//           canEditPassword = true;
//         }
//       }
//     }
//
//     return AlertDialog(
//       title: Text(widget.title),
//       content: SingleChildScrollView(
//         child: Form(
//           key: _formKey,
//           child: Column(
//             mainAxisSize: MainAxisSize.min,
//             children: [
//               // Champ Username.
//               TextFormField(
//                 controller: _usernameController,
//                 decoration: const InputDecoration(labelText: 'Username'),
//                 validator: (value) {
//                   if (value == null || value.isEmpty) {
//                     return 'Veuillez saisir un username.';
//                   }
//                   return null;
//                 },
//               ),
//               // Champ Roles (séparés par des virgules).
//               TextFormField(
//                 controller: _rolesController,
//                 decoration: const InputDecoration(
//                   labelText: 'Roles (séparés par des virgules)',
//                 ),
//                 validator: (value) {
//                   if (value == null || value.isEmpty) {
//                     return 'Veuillez saisir au moins un rôle.';
//                   }
//                   return null;
//                 },
//               ),
//               // Champ Sites (séparés par des virgules).
//               TextFormField(
//                 controller: _sitesController,
//                 decoration: const InputDecoration(
//                   labelText: 'Sites (séparés par des virgules)',
//                 ),
//                 validator: (value) {
//                   if (value == null || value.isEmpty) {
//                     return 'Veuillez saisir au moins un site.';
//                   }
//                   return null;
//                 },
//               ),
//               // Champ Password, affiché conditionnellement.
//               if (canEditPassword)
//                 TextFormField(
//                   controller: _passwordController,
//                   decoration: const InputDecoration(labelText: 'Password'),
//                   obscureText: true,
//                   // Le champ n'est pas requis : laisser vide signifie ne pas modifier le mot de passe.
//                 ),
//             ],
//           ),
//         ),
//       ),
//       actions: [
//         TextButton(
//           onPressed: () => Navigator.of(context).pop(null),
//           child: const Text('Annuler'),
//         ),
//         ElevatedButton(
//           onPressed: () {
//             if (_formKey.currentState!.validate()) {
//               final username = _usernameController.text.trim();
//               final rolesText = _rolesController.text.trim();
//               final sitesText = _sitesController.text.trim();
//               // Conversion en listes en séparant par des virgules.
//               final roles = rolesText
//                   .split(',')
//                   .map((r) => r.trim())
//                   .where((r) => r.isNotEmpty)
//                   .toList();
//               final sites = sitesText
//                   .split(',')
//                   .map((s) => s.trim())
//                   .where((s) => s.isNotEmpty)
//                   .toList();
//               final password = _passwordController.text.trim();
//
//               final result = <String, dynamic>{
//                 'username': username,
//                 'roles': roles,
//                 'sites': sites,
//               };
//               // Si l'utilisateur est autorisé à modifier le mot de passe et que le champ n'est pas vide,
//               // on l'ajoute au résultat ; sinon, on laisse la clé "password" absente.
//               if (canEditPassword && password.isNotEmpty) {
//                 result['password'] = password;
//               }
//               Navigator.of(context).pop(result);
//             }
//           },
//           child: Text(widget.confirmButtonText),
//         ),
//       ],
//     );
//   }
// }
