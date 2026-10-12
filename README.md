# GradeFlow — Automated Assignment Grading & Feedback

Flutter application for web, Linux, Windows and macOS, backed by FastAPI, PostgreSQL, Redis/RQ and isolated Docker grading workers. Built from the supplied automated academic assignment grading proposal.

## Features

- Animated responsive navigation, gradient dashboard, theme toggle, animated grade distribution and mobile drawer.
- Student registration, login and persistent JWT session; instructor and teaching-assistant access.
- Courses with enrollment codes, assignment creation, deadlines and public/hidden test cases.
- Python, Java and C++ source-file upload or code editing.
- Real Redis background queue, automatic result polling, test-by-test feedback, runtime and error output.
- Docker execution with no network, non-root user, read-only root filesystem, CPU/memory/process/time/output limits.
- Python AST and Java/C++ Tree-sitter structural analysis; variable-renaming-resistant structural similarity, complexity and style suggestions.
- Submission history, instructor score review, published feedback, regrading and grade CSV export.
- Demo accounts, three sample assignments, operator role management and CI checks.

**Delivery status:** Backend API/analysis tests and frontend validation results are recorded in `VALIDATION.md`. Docker execution must be validated on a machine with a running Docker Engine. This is an FYP implementation, not a security-certified public grading service. Similarity flags require human review. Input/output tests assess executable console programs; arbitrary instructor-written unit-test harnesses are not supported in this version.

## System requirements

| Component | Requirement |
|---|---|
| Flutter | Stable SDK with Dart >=3.4; use a recent stable release supporting CardThemeData and Color.withValues |
| Docker | Docker Engine + Compose v2 on Linux; Docker Desktop with Linux containers on Windows/macOS |
| Hardware | Suggested 8 GB RAM and 10+ GB free storage for runtime images |
| Python | Python 3.12 for optional local backend development; Python 3 for Linux/macOS bootstrap secret generation |
| Browser | Chrome or a modern browser |
| Linux desktop | clang, cmake, ninja-build, pkg-config, libgtk-3-dev, libstdc++-12-dev |
| Windows desktop | Visual Studio with Desktop development with C++ workload |
| macOS desktop | Xcode and its command-line tools; follow `flutter doctor` |

Desktop applications are built on their corresponding OS: Windows on Windows, macOS on macOS, Linux on Linux. Backend containers remain Linux containers on every host.

Install Flutter: https://docs.flutter.dev/get-started/install
Install Docker: https://docs.docker.com/get-started/get-docker/
Check prerequisites:

```sh
flutter doctor -v
docker version
docker compose version
```

On Ubuntu, install desktop build dependencies:

```sh
sudo apt update
sudo apt install clang cmake ninja-build pkg-config libgtk-3-dev libstdc++-12-dev
```

## 1. Get the code

Extract this project, or clone the GitHub repository after it is uploaded:

```sh
git clone https://github.com/ReallIkram/Automated-Academic-Assignment-Grading-Feedback-System.git
cd Automated-Academic-Assignment-Grading-Feedback-System
```

The folder containing `compose.yaml` is the project root.

## 2. Start the complete backend

Linux/macOS:

```sh
bash scripts/bootstrap.sh
```

Windows PowerShell (from the project root):

```powershell
powershell -ExecutionPolicy Bypass -File scripts/bootstrap.ps1
```

The scripts generate local random secrets in `.env`, build three sandbox images, start PostgreSQL, Redis, API and worker, then seed demo accounts. Keep `.env` private. Open it locally to find `DEMO_PASSWORD`; never commit it.

Manual alternative:

1. Copy `.env.example` to `.env`; replace the password and JWT secret with random alphanumeric values (JWT secret >=32 characters). Avoid punctuation in the database password unless URL-encoded.
2. Run:

```sh
docker build -f sandbox/python.Dockerfile -t gradeflow-python:local sandbox
docker build -f sandbox/java.Dockerfile -t gradeflow-java:local sandbox
docker build -f sandbox/cpp.Dockerfile -t gradeflow-cpp:local sandbox
docker compose up --build -d
docker compose run --rm api python -m app.seed
```

API: http://localhost:8000
Interactive API documentation: http://localhost:8000/docs
Health: http://localhost:8000/health

## 3. Run Flutter for web

Platform runner folders are included if generated during validation. If missing, generate them from the source with Flutter:

```sh
cd flutter_app
flutter create --project-name gradeflow --platforms=web,linux,windows,macos .
python3 ../scripts/configure_platforms.py
flutter pub get
flutter run -d chrome --web-port 3000 --dart-define=API_BASE_URL=http://localhost:8000
```

If Chrome is unavailable:

```sh
flutter run -d web-server --web-hostname localhost --web-port 3000 --dart-define=API_BASE_URL=http://localhost:8000
```

On Windows, use `python` instead of `python3` for the platform configuration command.

Open http://localhost:3000 in your browser. CORS permits this exact origin. If you choose another origin, edit `CORS_ORIGINS` in `.env` and recreate the API container with `docker compose up -d --force-recreate api`.

## 4. Run desktop

From `flutter_app`, use the command for your computer:

```sh
flutter run -d linux --dart-define=API_BASE_URL=http://localhost:8000
flutter run -d windows --dart-define=API_BASE_URL=http://localhost:8000
flutter run -d macos --dart-define=API_BASE_URL=http://localhost:8000
```

The API must remain running. macOS requires outgoing-network entitlement; run `python3 ../scripts/configure_platforms.py` after runner generation to enable outgoing requests. Release builds should use HTTPS for a remote API. Android/iOS are not packaged or validated; they can be added later with Flutter runners and platform network configuration.

## 5. Sign in and demonstrate the system

| Role | Email | Password |
|---|---|---|
| Instructor | instructor@gradeflow.local | DEMO_PASSWORD from `.env` |
| Student | student@gradeflow.local | Same generated password |
| Teaching assistant | ta@gradeflow.local | Same generated password |

Demo course enrollment code: `DEMO2026`.

1. Log in as the instructor; open Courses and Assignments. Three sample assignments are seeded.
2. Create a course or create an assignment in an existing course.
3. Log out, then sign in as the student or register a new student and join with the course code.
4. Open an assignment; paste source or upload `.py`, `.java` or `.cpp`.
5. Submit; the worker consumes Redis jobs. Results update every five seconds while grading is pending.
6. Open the submission report to inspect pass/fail results, diagnostics and style advice. Hidden test output is withheld from students.
7. Log in as the instructor; review results, inspect similarity candidates, publish a revised score/feedback, or regrade.
8. Open Analytics and export CSV.

The score is `maximum score × passed tests / number of tests`. Every test has equal weight. Compiler failure, timeout or wrong output fails that case. Output comparison trims leading/trailing whitespace but preserves internal whitespace.

## Assignment test format

Use a JSON array in the assignment dialog:

```json
[
  {"stdin": "2 3", "expected": "5", "hidden": false},
  {"stdin": "-3 10", "expected": "7", "hidden": true}
]
```

Deadline example: `2026-12-31T23:59:00+05:00`. UTC dates ending in `Z` also work. Java programs must use `public class Main`. C++ programs must include their own `main()` function. Python runs as a script reading stdin.

## Real instructor and TA accounts

Registration creates students only, preventing self-assigned instructor privileges. A trusted operator promotes registered users:

```sh
docker compose exec api python -m app.manage teacher@example.com instructor
docker compose exec api python -m app.manage assistant@example.com ta
```

TAs must enroll in a course with its enrollment code; they can then create assignments, inspect its class submissions, review and regrade. Instructors manage courses they own. Students see their own submissions only.

## Build release applications

```sh
cd flutter_app
flutter build web --release --dart-define=API_BASE_URL=https://YOUR_API_DOMAIN
flutter build linux --release --dart-define=API_BASE_URL=https://YOUR_API_DOMAIN
flutter build windows --release --dart-define=API_BASE_URL=https://YOUR_API_DOMAIN
flutter build macos --release --dart-define=API_BASE_URL=https://YOUR_API_DOMAIN
```

Run each desktop command on its respective OS. Serve `build/web` from a static host over HTTPS. Configure API HTTPS and the deployed frontend origin in CORS. The API URL is compile-time configuration; rebuild when it changes. For development on a different computer, expose the API intentionally, bind its port to a reachable interface and use the backend machine's IP instead of localhost.

## Optional local backend development

```sh
cd backend
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
export JWT_SECRET=local-development-secret-at-least-32-characters
export DATABASE_URL=sqlite:///./gradeflow.db
export REDIS_URL=redis://localhost:6379/0
export DEMO_PASSWORD=your-local-demo-password
python -m app.seed
uvicorn app.main:app --reload
```

On Windows activate `.venv\Scripts\Activate.ps1` and set variables with `$env:NAME='value'`. Run a second terminal with `rq worker grading --url redis://localhost:6379/0`. RQ's default forking worker is intended for Linux; use the Docker worker on Windows. Redis and sandbox Docker images are still required. There is no unsafe host execution fallback.

## Tests and diagnostics

```sh
cd backend
python -m pytest tests -q
cd ../flutter_app
flutter analyze
flutter test
```

API tests use a separate disposable SQLite database and stub only the sandbox call for orchestration checks. Real Docker integration tests are opt-in:

```sh
cd backend
RUN_DOCKER_TESTS=1 python -m pytest tests/test_sandbox.py -q
```

Logs and status:

```sh
docker compose ps
docker compose logs --tail=100 api worker
```

| Problem | Fix |
|---|---|
| Browser cannot connect | Start backend; verify `/health`, API_BASE_URL and exact CORS origin |
| Job remains queued | Inspect worker logs; confirm Redis and worker are running |
| Infrastructure error | Confirm sandbox images exist and worker can access the Docker socket |
| Java compile error | Use `public class Main`, standard input and console output |
| Time limit exceeded | Remove infinite loops; simplify the solution |
| macOS network failure | Enable outgoing client network entitlement; use HTTPS remotely |
| Enrollment fails | Copy the course code exactly |
| Desktop device missing | Run `flutter doctor`, install native build tools, regenerate runners |
| Demo login fails | Read DEMO_PASSWORD from `.env`; existing seed users are not reset automatically |

Stop with `docker compose down`. Data persists in named volumes. `docker compose down -v` deletes the local database and queue data; only use it when you intentionally want to reset the installation.

## Architecture and repository layout

```text
flutter_app/       Flutter source, runners and widget tests
backend/app/       API, persistence, authentication, analysis, grading jobs
backend/tests/     Permission, privacy, analysis, orchestration and Docker tests
sandbox/           Python / Java / C++ runtime Dockerfiles
scripts/           Linux/macOS and Windows bootstrap
compose.yaml       PostgreSQL + Redis + API + worker
.github/workflows/ Automated backend and Flutter checks
```

Flutter → authenticated REST API → PostgreSQL metadata / Redis queue → trusted worker → isolated per-test Docker container → stored feedback → Flutter polling and reports.

## Limits and deployment notes

- Structural similarity compares normalized node-type sequences, not semantic equivalence or a trained plagiarism classifier. It can produce false positives for short, similar assignments. Compare only within the same assignment and review candidates manually.
- Complexity and style checks are heuristics. Python has docstring, line-length and bare-except checks; Java/C++ use Tree-sitter syntax structure and generic complexity/line-length checks.
- Five seconds wall time per test includes compilation for Java/C++; slow machines may need a larger runner timeout. 256 MB memory, one CPU and 64 processes per container are configured. Output is capped using file limits and truncated in stored results.
- The worker has Docker socket access, which grants powerful host capabilities. Run it on a dedicated grading host/VM, keep Docker/kernel patched and never mount the socket in student containers. The API has no socket access. Containers reduce risk but do not guarantee protection from every kernel exploit.
- Authentication uses bcrypt passwords and expiring JWTs. Add HTTPS, request-rate limiting, institution provisioning, migration tooling, backups and operational monitoring before exposing a public service. Logout removes the client token; tokens expire after eight hours and are not centrally revoked.
- Only console-program grading is implemented. GUI, essays, hardware programs and deployed web apps remain outside the proposal's phase-one scope.

Reference documentation: https://docs.flutter.dev/platform-integration/desktop and https://docs.docker.com/engine/security/.
