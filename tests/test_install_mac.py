import json
from pathlib import Path
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "install_mac.sh"


class InstallerTests(unittest.TestCase):
    def shell(self, body, *args, cwd=None, input=None):
        # Guard against real installation if the source-only entry point regresses.
        bootstrap = '''
            brew() { return 97; }; git() { return 97; }; sh() { return 97; }
            curl() { return 97; }; ln() { return 97; }; mv() { return 97; }
            mkdir() { return 97; }
            source "$1"; shift
            unset -f brew git sh curl ln mv mkdir
        '''
        return subprocess.run(
            ["bash", "-c", bootstrap + body, "bash", str(SCRIPT), *map(str, args)],
            cwd=cwd or ROOT, text=True, capture_output=True, input=input,
        )

    def test_sourcing_does_not_run_installation(self):
        result = self.shell('printf "sourced"')
        self.assertEqual((result.returncode, result.stdout), (0, "sourced"))

    def test_tools_can_be_selected_without_running_shell_setup(self):
        result = self.shell('install_homebrew() { :; }; brew() { :; }; install_tools() { echo tools; }; install_shell() { echo shell; }; main tools')
        self.assertEqual((result.returncode, result.stdout), (0, "tools\n"))

    def test_invalid_stage_fails_before_homebrew_runs(self):
        result = self.shell('install_homebrew() { echo unexpected; }; install_shell() { echo unexpected; return 98; }; main unknown')
        self.assertNotEqual(result.returncode, 0)
        self.assertNotIn("unexpected", result.stdout)

    def test_required_package_failure_stops_tools_configuration(self):
        result = self.shell('brew() { [[ "$1" != install || "$*" != *ripgrep* ]]; }; sym_link() { echo unexpected; return 31; }; install_tools')
        self.assertNotEqual(result.returncode, 0)
        self.assertNotIn("unexpected", result.stdout)

    def test_package_updates_are_limited_to_requested_packages(self):
        result = self.shell('brew() { printf "%s\\n" "$*"; }; install_packages --formula tmux just')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.splitlines(), ["install --formula tmux just", "upgrade --formula tmux just"])

    def test_source_paths_do_not_depend_on_current_directory(self):
        with tempfile.TemporaryDirectory() as directory:
            result = self.shell('printf "%s" "$ROOT_PATH"', cwd=directory)
        self.assertEqual((result.returncode, result.stdout), (0, str(ROOT)))

    def test_language_setup_installs_cross_targets_for_stable_and_nightly(self):
        result = self.shell('''
            install_packages() { :; }
            curl() { echo :; }
            bash() { :; }
            rustup() { printf '%s\\n' "$*"; }
            cargo() { :; }
            sym_link() { :; }
            install_languages
        ''')
        self.assertEqual(result.returncode, 0, result.stderr)
        installs = [line.split() for line in result.stdout.splitlines()
                    if line.startswith("target add ")]
        for toolchain in ("stable", "nightly"):
            with self.subTest(toolchain=toolchain):
                self.assertTrue(any(
                    "wasm32-wasip1" in command and command[-2:] == ["--toolchain", toolchain]
                    for command in installs
                ), f"Missing WASI target for {toolchain}: {result.stdout}")

    def test_git_setup_fills_missing_name_without_overwriting_email(self):
        with tempfile.TemporaryDirectory() as directory:
            config = Path(directory) / "gitconfig"
            config.write_text('[user]\n    email = existing@example.com\n')
            result = self.shell('export GIT_CONFIG_GLOBAL="$1" GIT_CONFIG_NOSYSTEM=1; setup_git',
                                config, input="New Name\n")
            self.assertEqual(result.returncode, 0, result.stderr)
            name = subprocess.check_output(['git', 'config', '--file', str(config), '--get', 'user.name'], text=True)
            email = subprocess.check_output(['git', 'config', '--file', str(config), '--get', 'user.email'], text=True)
            self.assertEqual(name.strip(), "New Name")
            self.assertEqual(email.strip(), "existing@example.com")

    def test_git_setup_fills_missing_email_without_overwriting_name(self):
        with tempfile.TemporaryDirectory() as directory:
            config = Path(directory) / "gitconfig"
            config.write_text('[user]\n    name = Existing Name\n')
            result = self.shell('export GIT_CONFIG_GLOBAL="$1" GIT_CONFIG_NOSYSTEM=1; setup_git',
                                config, input="new@example.com\n")
            self.assertEqual(result.returncode, 0, result.stderr)
            name = subprocess.check_output(['git', 'config', '--file', str(config), '--get', 'user.name'], text=True)
            email = subprocess.check_output(['git', 'config', '--file', str(config), '--get', 'user.email'], text=True)
            self.assertEqual(name.strip(), "Existing Name")
            self.assertEqual(email.strip(), "new@example.com")

    def test_existing_directory_is_backed_up_before_linking(self):
        with tempfile.TemporaryDirectory() as directory:
            source = Path(directory) / "source"
            source.mkdir()
            dest = Path(directory) / "dest"
            dest.mkdir()
            (dest / "personal").write_text("keep")
            result = self.shell('sym_link "$1" "$2"', source, dest)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertTrue(dest.is_symlink())
            self.assertEqual((Path(str(dest) + ".bak") / "personal").read_text(), "keep")

    def test_correct_link_is_idempotent(self):
        with tempfile.TemporaryDirectory() as directory:
            source = Path(directory) / "source"
            source.touch()
            dest = Path(directory) / "dest"
            dest.symlink_to(source)
            result = self.shell('sym_link "$1" "$2"', source, dest)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertFalse(Path(str(dest) + ".bak").exists())

    def test_broken_destination_link_is_preserved_in_backup(self):
        with tempfile.TemporaryDirectory() as directory:
            source, dest = Path(directory) / "source", Path(directory) / "dest"
            source.touch()
            dest.symlink_to("missing")
            result = self.shell('sym_link "$1" "$2"', source, dest)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(dest.resolve(), source.resolve())
            self.assertEqual(Path(str(dest) + ".bak").readlink(), Path("missing"))

    def test_existing_backup_is_never_overwritten(self):
        with tempfile.TemporaryDirectory() as directory:
            source, dest = Path(directory) / "source", Path(directory) / "dest"
            source.touch()
            dest.write_text("current")
            backup = Path(str(dest) + ".bak")
            backup.write_text("previous")
            result = self.shell('sym_link "$1" "$2"', source, dest)
            self.assertNotEqual(result.returncode, 0)
            self.assertEqual(backup.read_text(), "previous")
            self.assertEqual(dest.read_text(), "current")

    def test_missing_source_leaves_destination_untouched(self):
        with tempfile.TemporaryDirectory() as directory:
            dest = Path(directory) / "dest"
            dest.write_text("keep")
            result = self.shell('sym_link "$1" "$2"', Path(directory) / "missing", dest)
            self.assertNotEqual(result.returncode, 0)
            self.assertEqual(dest.read_text(), "keep")

    def configure_docker(self, directory):
        return self.shell('export DOCKER_CONFIG="$1"; brew() { echo /test/brew; }; configure_docker', directory)

    def test_docker_registration_preserves_other_settings(self):
        with tempfile.TemporaryDirectory() as directory:
            config = Path(directory) / "config.json"
            config.write_text(json.dumps({"credsStore": "osxkeychain", "cliPluginsExtraDirs": ["/custom"]}))
            result = self.configure_docker(directory)
            self.assertEqual(result.returncode, 0, result.stderr)
            data = json.loads(config.read_text())
            self.assertEqual(data["credsStore"], "osxkeychain")
            self.assertCountEqual(data["cliPluginsExtraDirs"], ["/custom", "/test/brew/lib/docker/cli-plugins"])

    def test_repeated_docker_registration_does_not_duplicate_plugin_path(self):
        with tempfile.TemporaryDirectory() as directory:
            for _ in range(2):
                result = self.configure_docker(directory)
                self.assertEqual(result.returncode, 0, result.stderr)
            data = json.loads((Path(directory) / "config.json").read_text())
            self.assertEqual(data["cliPluginsExtraDirs"], ["/test/brew/lib/docker/cli-plugins"])

    def test_missing_docker_config_is_created(self):
        with tempfile.TemporaryDirectory() as directory:
            result = self.configure_docker(directory)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(json.loads((Path(directory) / "config.json").read_text()),
                             {"cliPluginsExtraDirs": ["/test/brew/lib/docker/cli-plugins"]})

    def test_docker_registration_updates_symlink_target_and_preserves_link(self):
        for relative in (False, True):
            with self.subTest(relative=relative), tempfile.TemporaryDirectory() as directory:
                root = Path(directory)
                target_dir = root / "shared settings"
                target_dir.mkdir()
                target = target_dir / "docker.json"
                target.write_text("{}")
                config = root / "config.json"
                link_target = target.relative_to(root) if relative else target
                config.symlink_to(link_target)
                result = self.configure_docker(directory)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertTrue(config.is_symlink())
                self.assertEqual(config.readlink(), link_target)
                self.assertEqual(json.loads(target.read_text()),
                                 {"cliPluginsExtraDirs": ["/test/brew/lib/docker/cli-plugins"]})

    def test_unresolved_docker_config_link_is_rejected_without_changes(self):
        for target in ("missing", "config.json"):
            with self.subTest(target=target), tempfile.TemporaryDirectory() as directory:
                config = Path(directory) / "config.json"
                config.symlink_to(target)
                result = self.configure_docker(directory)
                self.assertNotEqual(result.returncode, 0)
                self.assertIn("link", result.stderr)
                self.assertEqual(config.readlink(), Path(target))
                self.assertEqual(list(Path(directory).iterdir()), [config])

    def test_invalid_docker_config_is_preserved_without_temporary_files(self):
        for content in ["{invalid", "", "{}{}", '{"cliPluginsExtraDirs":"wrong"}', '{"cliPluginsExtraDirs":false}']:
            with self.subTest(content=content), tempfile.TemporaryDirectory() as directory:
                config = Path(directory) / "config.json"
                config.write_text(content)
                result = self.configure_docker(directory)
                self.assertNotEqual(result.returncode, 0)
                self.assertEqual(config.read_text(), content)
                self.assertEqual(list(Path(directory).iterdir()), [config])


if __name__ == "__main__":
    unittest.main()
