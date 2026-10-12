import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api.dart';

void main() => runApp(const GradeFlow());
const purple = Color(0xff7357ef);
const ink = Color(0xff17213e);

class GradeFlow extends StatefulWidget {
  const GradeFlow({super.key});
  @override
  State<GradeFlow> createState() => _GradeFlowState();
}

class _GradeFlowState extends State<GradeFlow> {
  final api = Api();
  Map<String, dynamic>? user;
  bool dark = false;
  @override
  void initState() {
    super.initState();
    restore();
  }

  Future<void> restore() async {
    final p = await SharedPreferences.getInstance();
    api.token = p.getString('token');
    if (api.token != null) {
      try {
        final u = await api.call('/me');
        if (mounted) setState(() => user = Map<String, dynamic>.from(u));
      } catch (_) {
        api.token = null;
        await p.remove('token');
      }
    }
  }

  Future<void> login(Map<String, dynamic> result) async {
    api.token = result['token'];
    await (await SharedPreferences.getInstance()).setString(
      'token',
      api.token!,
    );
    if (mounted)
      setState(() => user = Map<String, dynamic>.from(result['user']));
  }

  Future<void> logout() async {
    api.token = null;
    await (await SharedPreferences.getInstance()).remove('token');
    if (mounted) setState(() => user = null);
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'GradeFlow',
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: purple,
        brightness: dark ? Brightness.dark : Brightness.light,
      ),
      scaffoldBackgroundColor: dark
          ? const Color(0xff111727)
          : const Color(0xfff5f6fc),
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(14)),
        ),
        filled: true,
      ),
      cardTheme: const CardThemeData(elevation: 0),
    ),
    home: AnimatedSwitcher(
      duration: const Duration(milliseconds: 450),
      child: user == null
          ? LoginScreen(key: const ValueKey('login'), api: api, onLogin: login)
          : Workspace(
              key: ValueKey(user!['id']),
              api: api,
              user: user!,
              logout: logout,
              toggleTheme: () => setState(() => dark = !dark),
            ),
    ),
  );
}

class LoginScreen extends StatefulWidget {
  final Api api;
  final Future<void> Function(Map<String, dynamic>) onLogin;
  const LoginScreen({super.key, required this.api, required this.onLogin});
  @override
  State<LoginScreen> createState() => _LoginState();
}

class _LoginState extends State<LoginScreen> {
  final email = TextEditingController(),
      password = TextEditingController(),
      name = TextEditingController();
  bool register = false, busy = false;
  String? error;
  @override
  void dispose() {
    email.dispose();
    password.dispose();
    name.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      if (register)
        await widget.api.call(
          '/auth/register',
          data: {
            'name': name.text,
            'email': email.text,
            'password': password.text,
          },
        );
      final r = await widget.api.call(
        '/auth/login',
        data: {'email': email.text, 'password': password.text},
      );
      await widget.onLogin(Map<String, dynamic>.from(r));
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 48,
            runSpacing: 32,
            children: [
              SizedBox(
                width: 380,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.auto_awesome_rounded,
                      size: 62,
                      color: purple,
                    ),
                    const SizedBox(height: 22),
                    const Text(
                      'GradeFlow',
                      style: TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.w900,
                        color: purple,
                      ),
                    ),
                    const Text(
                      'Great code deserves\ngreat feedback.',
                      style: TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Your programming classroom, connected. Submit, evaluate and improve in one beautiful workspace.',
                      style: TextStyle(fontSize: 17, height: 1.6),
                    ),
                    const SizedBox(height: 26),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        'Python',
                        'Java',
                        'C++',
                        'AST analysis',
                        'Docker grading',
                      ].map((t) => Chip(label: Text(t))).toList(),
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: 400,
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(28),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          register ? 'Create your account' : 'Welcome back',
                          style: const TextStyle(
                            fontSize: 27,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          register
                              ? 'Student accounts are ready immediately.'
                              : 'Sign in to your learning workspace.',
                        ),
                        const SizedBox(height: 24),
                        if (register) ...[
                          TextField(
                            controller: name,
                            decoration: const InputDecoration(
                              labelText: 'Full name',
                            ),
                          ),
                          const SizedBox(height: 14),
                        ],
                        TextField(
                          controller: email,
                          decoration: const InputDecoration(
                            labelText: 'Email',
                            prefixIcon: Icon(Icons.alternate_email),
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          controller: password,
                          obscureText: true,
                          onSubmitted: (_) {
                            if (!busy) submit();
                          },
                          decoration: const InputDecoration(
                            labelText: 'Password',
                            prefixIcon: Icon(Icons.lock_outline),
                          ),
                        ),
                        if (error != null)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Text(
                              error!,
                              style: const TextStyle(color: Colors.red),
                            ),
                          ),
                        const SizedBox(height: 22),
                        FilledButton(
                          onPressed: busy ? null : submit,
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: busy
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Text(register ? 'Create account' : 'Sign in'),
                          ),
                        ),
                        TextButton(
                          onPressed: busy
                              ? null
                              : () => setState(() => register = !register),
                          child: Text(
                            register
                                ? 'Already registered? Sign in'
                                : 'New student? Create an account',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class Workspace extends StatefulWidget {
  final Api api;
  final Map<String, dynamic> user;
  final VoidCallback logout, toggleTheme;
  const Workspace({
    super.key,
    required this.api,
    required this.user,
    required this.logout,
    required this.toggleTheme,
  });
  @override
  State<Workspace> createState() => _WorkspaceState();
}

class _WorkspaceState extends State<Workspace> {
  List<dynamic> courses = [], assignments = [], submissions = [];
  int page = 0;
  bool loading = true;
  String? error;
  Timer? timer;
  bool get staff => widget.user['role'] != 'student';
  @override
  void initState() {
    super.initState();
    load();
    timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (submissions.any(
        (s) => s['status'] == 'queued' || s['status'] == 'running',
      ))
        load(silent: true);
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  Future<void> load({bool silent = false}) async {
    if (!silent) setState(() => loading = true);
    try {
      final data = await Future.wait([
        widget.api.call('/courses'),
        widget.api.call('/assignments'),
        widget.api.call('/submissions'),
      ]);
      if (mounted)
        setState(() {
          courses = data[0];
          assignments = data[1];
          submissions = data[2];
          error = null;
        });
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void message(String t) {
    if (mounted)
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t)));
  }

  Future<void> action(Future<void> Function() task) async {
    try {
      await task();
      await load();
    } catch (e) {
      message(e.toString());
    }
  }

  Future<void> courseDialog() async {
    final text = TextEditingController();
    String? err;
    bool busy = false;
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, update) => AlertDialog(
          title: Text(staff ? 'Create course' : 'Join a course'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: text,
                decoration: InputDecoration(
                  labelText: staff ? 'Course title' : 'Enrollment code',
                ),
              ),
              if (err != null)
                Text(err!, style: const TextStyle(color: Colors.red)),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: busy
                  ? null
                  : () async {
                      update(() => busy = true);
                      try {
                        await widget.api.call(
                          staff ? '/courses' : '/courses/enroll',
                          data: staff
                              ? {'title': text.text}
                              : {'code': text.text},
                        );
                        if (ctx.mounted) Navigator.pop(ctx);
                        await load();
                      } catch (e) {
                        update(() {
                          busy = false;
                          err = e.toString();
                        });
                      }
                    },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    text.dispose();
  }

  Future<void> assignmentDialog() async {
    final title = TextEditingController(),
        description = TextEditingController(),
        deadline = TextEditingController(
          text: DateTime.now()
              .add(const Duration(days: 7))
              .toUtc()
              .toIso8601String(),
        ),
        tests = TextEditingController(
          text: const JsonEncoder.withIndent('  ').convert([
            {'stdin': '2 3', 'expected': '5', 'hidden': false},
            {'stdin': '-3 10', 'expected': '7', 'hidden': true},
          ]),
        );
    final owned = courses
        .where(
          (c) => c['owner'] == widget.user['id'] || widget.user['role'] == 'ta',
        )
        .toList();
    if (owned.isEmpty) {
      message('Create a course first.');
      return;
    }
    int course = owned.first['id'];
    String language = 'python';
    String? err;
    bool busy = false;
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, update) => AlertDialog(
          title: const Text('New programming assignment'),
          content: SizedBox(
            width: 620,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<int>(
                    value: course,
                    items: owned
                        .map(
                          (c) => DropdownMenuItem<int>(
                            value: c['id'],
                            child: Text(c['title']),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => course = v!,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: title,
                    decoration: const InputDecoration(labelText: 'Title'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: description,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Instructions',
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: language,
                    items: ['python', 'java', 'cpp']
                        .map((l) => DropdownMenuItem(value: l, child: Text(l)))
                        .toList(),
                    onChanged: (v) => language = v!,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: deadline,
                    decoration: const InputDecoration(
                      labelText: 'Deadline · ISO date with timezone',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: tests,
                    maxLines: 8,
                    style: const TextStyle(fontFamily: 'monospace'),
                    decoration: const InputDecoration(
                      labelText: 'Test cases · JSON stdin / expected / hidden',
                    ),
                  ),
                  if (err != null)
                    Text(err!, style: const TextStyle(color: Colors.red)),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: busy
                  ? null
                  : () async {
                      update(() => busy = true);
                      try {
                        await widget.api.call(
                          '/assignments',
                          data: {
                            'course_id': course,
                            'title': title.text,
                            'description': description.text,
                            'language': language,
                            'deadline': deadline.text,
                            'tests': jsonDecode(tests.text),
                            'max_score': 100,
                          },
                        );
                        if (ctx.mounted) Navigator.pop(ctx);
                        await load();
                      } catch (e) {
                        update(() {
                          busy = false;
                          err = e.toString();
                        });
                      }
                    },
              child: const Text('Publish assignment'),
            ),
          ],
        ),
      ),
    );
    for (final c in [title, description, deadline, tests]) {
      c.dispose();
    }
  }

  Future<void> submitDialog(dynamic a) async {
    final code = TextEditingController(
      text: a['language'] == 'python'
          ? 'a, b = map(int, input().split())\nprint(a + b)\n'
          : a['language'] == 'java'
          ? 'import java.util.Scanner;\npublic class Main {\n  public static void main(String[] args) {\n    Scanner s = new Scanner(System.in);\n    System.out.println(s.nextInt() + s.nextInt());\n  }\n}\n'
          : '#include <iostream>\nint main() { int a,b; std::cin >> a >> b; std::cout << a+b; }\n',
    );
    String? err;
    bool busy = false;
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, update) => AlertDialog(
          title: Text(a['title']),
          content: SizedBox(
            width: 760,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(a['description']),
                  const SizedBox(height: 12),
                  Text('Deadline: ${a['deadline']}'),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () async {
                      try {
                        final f = await FilePicker.platform.pickFiles(
                          withData: true,
                          type: FileType.custom,
                          allowedExtensions: [
                            a['language'] == 'python'
                                ? 'py'
                                : a['language'] == 'java'
                                ? 'java'
                                : 'cpp',
                          ],
                        );
                        if (f != null && f.files.single.bytes != null) {
                          code.text = utf8.decode(f.files.single.bytes!);
                        }
                      } catch (e) {
                        update(() => err = e.toString());
                      }
                    },
                    icon: const Icon(Icons.upload_file),
                    label: const Text('Upload source file'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: code,
                    maxLines: 15,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 14,
                    ),
                    decoration: const InputDecoration(labelText: 'Source code'),
                  ),
                  const SizedBox(height: 12),
                  ...((a['tests'] as List).map(
                    (t) =>
                        Text('Example stdin: ${t['stdin']} → ${t['expected']}'),
                  )),
                  if (err != null)
                    Text(err!, style: const TextStyle(color: Colors.red)),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              onPressed: busy
                  ? null
                  : () async {
                      update(() => busy = true);
                      try {
                        await widget.api.call(
                          '/submissions',
                          data: {'assignment_id': a['id'], 'code': code.text},
                        );
                        if (ctx.mounted) Navigator.pop(ctx);
                        await load();
                        message(
                          'Submission queued. Results update automatically.',
                        );
                      } catch (e) {
                        update(() {
                          busy = false;
                          err = e.toString();
                        });
                      }
                    },
              icon: const Icon(Icons.rocket_launch),
              label: const Text('Submit for grading'),
            ),
          ],
        ),
      ),
    );
    code.dispose();
  }

  Future<void> showReport(dynamic s) async {
    final report = s['report'] ?? {};
    final score = TextEditingController(text: (s['score'] ?? 0).toString()),
        feedback = TextEditingController(text: s['instructor_feedback'] ?? '');
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${s['title']} · ${s['student']}'),
        content: SizedBox(
          width: 740,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${s['score'] ?? '—'} / ${s['max_score']}',
                  style: const TextStyle(
                    fontSize: 38,
                    fontWeight: FontWeight.bold,
                    color: purple,
                  ),
                ),
                Text('Status: ${s['status']}'),
                const SizedBox(height: 16),
                Text(report['feedback'] ?? 'Waiting for grading…'),
                if (s['instructor_feedback'] != null) ...[
                  const SizedBox(height: 12),
                  Text('Instructor: ${s['instructor_feedback']}'),
                ],
                const SizedBox(height: 16),
                ...((report['tests'] ?? []) as List).map(
                  (t) => ListTile(
                    leading: Icon(
                      t['passed'] == true ? Icons.check_circle : Icons.cancel,
                      color: t['passed'] == true ? Colors.teal : Colors.red,
                    ),
                    title: Text(
                      '${t['name']}${t['hidden'] == true ? ' · Hidden test' : ''}',
                    ),
                    subtitle: Text(
                      t['hidden'] == true && !s['can_manage']
                          ? 'Result only'
                          : 'stdout: ${t['stdout'] ?? ''}\nstderr: ${t['stderr'] ?? ''}\nTime: ${t['seconds'] ?? 0}s',
                    ),
                  ),
                ),
                if (report['analysis'] != null) ...[
                  Text(
                    'Cyclomatic complexity: ${report['analysis']['complexity']}',
                  ),
                  ...((report['analysis']['warnings'] ?? []) as List).map(
                    (w) => Text('• $w'),
                  ),
                ],
                if (s['can_manage'] == true) ...[
                  const SizedBox(height: 16),
                  const Text(
                    'Structural similarity flags · instructor review required',
                  ),
                  ...((report['matches'] ?? []) as List).map(
                    (m) => Text(
                      'Submission #${m['submission_id']}: ${m['similarity']}%',
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: score,
                    decoration: const InputDecoration(
                      labelText: 'Reviewed score',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: feedback,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Instructor feedback',
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await Clipboard.setData(
                ClipboardData(
                  text: const JsonEncoder.withIndent('  ').convert(s),
                ),
              );
              message('Report copied.');
            },
            child: const Text('Copy report'),
          ),
          if (s['can_manage'] == true) ...[
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                action(
                  () => widget.api
                      .call('/submissions/${s['id']}/regrade', data: {})
                      .then((_) {}),
                );
              },
              child: const Text('Regrade'),
            ),
            FilledButton(
              onPressed: () {
                final value = double.tryParse(score.text);
                if (value == null) {
                  message('Enter a numeric score.');
                  return;
                }
                final data = {
                  'score': value,
                  'feedback': feedback.text,
                  'published': true,
                };
                Navigator.pop(ctx);
                action(
                  () => widget.api
                      .call('/submissions/${s['id']}/review', data: data)
                      .then((_) {}),
                );
              },
              child: const Text('Publish review'),
            ),
          ],
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
    score.dispose();
    feedback.dispose();
  }

  Widget metric(String label, String value, IconData icon, Color color) =>
      SizedBox(
        width: 230,
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: color, size: 30),
                const SizedBox(height: 16),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(label),
              ],
            ),
          ),
        ),
      );
  Widget dashboard() {
    final done = submissions.where((s) => s['status'] == 'completed').toList();
    final avg = done.isEmpty
        ? 0.0
        : done
                  .map(
                    (s) =>
                        (s['score'] as num).toDouble() /
                        (s['max_score'] as num) *
                        100,
                  )
                  .reduce((a, b) => a + b) /
              done.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(30),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [purple, Color(0xffac64e9), Color(0xfff190a6)],
            ),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'LEARN • BUILD • IMPROVE',
                style: TextStyle(color: Colors.white70, letterSpacing: 2),
              ),
              const SizedBox(height: 12),
              Text(
                'Hello, ${widget.user['name']} 👋',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'A clearer picture of every submission.',
                style: TextStyle(color: Colors.white, fontSize: 17),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            metric('Courses', courses.length.toString(), Icons.school, purple),
            metric(
              'Assignments',
              assignments.length.toString(),
              Icons.code,
              Colors.blue,
            ),
            metric(
              'Submissions',
              submissions.length.toString(),
              Icons.upload,
              Colors.orange,
            ),
            metric(
              'Average score',
              '${avg.toStringAsFixed(1)}%',
              Icons.insights,
              Colors.teal,
            ),
          ],
        ),
        const SizedBox(height: 24),
        const Text(
          'Recent activity',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        if (submissions.isEmpty)
          empty('Your submission history will appear here.'),
        ...submissions.take(5).map(submissionCard),
      ],
    );
  }

  Widget empty(String text) => Card(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Row(
        children: [
          const Icon(Icons.inbox_outlined, color: purple, size: 32),
          const SizedBox(width: 16),
          Expanded(child: Text(text)),
        ],
      ),
    ),
  );
  Widget submissionCard(dynamic s) => Card(
    child: ListTile(
      contentPadding: const EdgeInsets.all(16),
      leading: CircleAvatar(
        backgroundColor: purple.withValues(alpha: .12),
        child: Icon(
          s['status'] == 'completed' ? Icons.task_alt : Icons.hourglass_top,
          color: purple,
        ),
      ),
      title: Text(
        s['title'],
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      subtitle: Text('${s['student']} · ${s['status']} · ${s['created_at']}'),
      trailing: Text(
        '${s['score'] ?? '—'} / ${s['max_score']}',
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      onTap: () => showReport(s),
    ),
  );
  Widget body() {
    if (page == 0) return dashboard();
    if (page == 1)
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FilledButton.icon(
            onPressed: courseDialog,
            icon: Icon(staff ? Icons.add : Icons.login),
            label: Text(staff ? 'Create course' : 'Join course'),
          ),
          const SizedBox(height: 18),
          if (courses.isEmpty)
            empty('Join a course using the code from your instructor.'),
          ...courses.map(
            (c) => Card(
              child: ListTile(
                leading: const Icon(Icons.school, color: purple),
                title: Text(c['title']),
                subtitle: Text('Enrollment code: ${c['code']}'),
                trailing: IconButton(
                  icon: const Icon(Icons.copy),
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: c['code']));
                    message('Enrollment code copied.');
                  },
                ),
              ),
            ),
          ),
        ],
      );
    if (page == 2)
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (staff)
            FilledButton.icon(
              onPressed: assignmentDialog,
              icon: const Icon(Icons.add),
              label: const Text('Create assignment'),
            ),
          const SizedBox(height: 16),
          if (assignments.isEmpty) empty('No assignments in your courses yet.'),
          ...assignments.map(
            (a) => Card(
              child: Padding(
                padding: const EdgeInsets.all(22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Chip(
                          label: Text(a['language'].toString().toUpperCase()),
                        ),
                        const Spacer(),
                        Text('${a['max_score']} points'),
                      ],
                    ),
                    Text(
                      a['title'],
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(a['description']),
                    const SizedBox(height: 12),
                    Text('Due ${a['deadline']}'),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: () => submitDialog(a),
                      icon: const Icon(Icons.code),
                      label: const Text('Open & submit'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      );
    if (page == 3)
      return Column(
        children: [
          if (submissions.isEmpty)
            empty('Submit code to see your grading results.'),
          ...submissions.map(submissionCard),
        ],
      );
    final completed = submissions
        .where((s) => s['status'] == 'completed')
        .toList();
    final bands = [0, 0, 0, 0, 0];
    for (final s in completed) {
      final percent = (s['score'] as num) / (s['max_score'] as num) * 100;
      bands[(percent / 20).floor().clamp(0, 4).toInt()]++;
    }
    final total = completed.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Grade distribution',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 22),
        ...List.generate(
          5,
          (i) => Padding(
            padding: const EdgeInsets.only(bottom: 18),
            child: Row(
              children: [
                SizedBox(
                  width: 88,
                  child: Text('${i * 20}–${i == 4 ? 100 : i * 20 + 19}%'),
                ),
                Expanded(
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(
                      begin: 0,
                      end: total == 0 ? 0 : bands[i] / total,
                    ),
                    duration: const Duration(milliseconds: 750),
                    builder: (ctx, v, _) => LinearProgressIndicator(
                      value: v,
                      minHeight: 16,
                      borderRadius: BorderRadius.circular(10),
                      color: [
                        Colors.red,
                        Colors.orange,
                        Colors.blue,
                        purple,
                        Colors.teal,
                      ][i],
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Text('${bands[i]}'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: () async {
            try {
              final csv = await widget.api.call('/reports.csv');
              await FilePicker.platform.saveFile(
                dialogTitle: 'Save grade report',
                fileName: 'grades.csv',
                bytes: utf8.encode(csv),
                type: FileType.custom,
                allowedExtensions: ['csv'],
              );
            } catch (e) {
              message(e.toString());
            }
          },
          icon: const Icon(Icons.download),
          label: const Text('Export grades CSV'),
        ),
        const SizedBox(height: 24),
        const Text(
          'Similarity flags identify candidates for human review. They are not proof of plagiarism.',
        ),
        ...completed
            .where((s) => ((s['report'] ?? {})['matches'] ?? []).isNotEmpty)
            .map(submissionCard),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    const labels = [
      'Overview',
      'Courses',
      'Assignments',
      'Submissions',
      'Analytics',
    ];
    const icons = [
      Icons.dashboard_rounded,
      Icons.school_rounded,
      Icons.code_rounded,
      Icons.task_rounded,
      Icons.insights_rounded,
    ];
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final navigation = ListView(
      children: [
        const Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            '✦ GradeFlow',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: purple,
            ),
          ),
        ),
        ...List.generate(
          labels.length,
          (i) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: ListTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              selected: page == i,
              selectedTileColor: purple.withValues(alpha: .12),
              leading: Icon(icons[i]),
              title: Text(labels[i]),
              onTap: () {
                setState(() => page = i);
                if (!wide) Navigator.pop(context);
              },
            ),
          ),
        ),
        const Divider(),
        ListTile(
          title: Text(widget.user['name']),
          subtitle: Text(widget.user['role']),
        ),
        ListTile(
          leading: const Icon(Icons.logout),
          title: const Text('Sign out'),
          onTap: widget.logout,
        ),
      ],
    );
    return Scaffold(
      appBar: AppBar(
        title: Text(labels[page]),
        actions: [
          IconButton(
            onPressed: widget.toggleTheme,
            icon: const Icon(Icons.brightness_6_outlined),
          ),
          IconButton(onPressed: () => load(), icon: const Icon(Icons.refresh)),
          const SizedBox(width: 16),
        ],
      ),
      drawer: wide ? null : Drawer(child: navigation),
      body: Row(
        children: [
          if (wide) SizedBox(width: 245, child: navigation),
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : error != null
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(error!),
                        const SizedBox(height: 12),
                        FilledButton(
                          onPressed: () => load(),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  )
                : SingleChildScrollView(
                    padding: EdgeInsets.all(wide ? 32 : 16),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 350),
                      transitionBuilder: (child, animation) => FadeTransition(
                        opacity: animation,
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0, .04),
                            end: Offset.zero,
                          ).animate(animation),
                          child: child,
                        ),
                      ),
                      child: Container(key: ValueKey(page), child: body()),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
