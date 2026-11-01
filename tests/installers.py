"""Linux installer tests: fake Git/Neovim, temporary HOME/XDG, no network."""
from pathlib import Path
import json
import os
import shutil
import subprocess
import tempfile
import unittest

REPO = Path(__file__).resolve().parents[1]
FAKE = r'''#!/usr/bin/python3
import json, os, sys
from pathlib import Path
name=Path(sys.argv[0]).name
args=sys.argv[1:]
with open(os.environ['FAKE_LOG'],'a') as f:
    f.write(json.dumps([name,args,os.getenv('NVIM_APPNAME')])+'\n')
if name=='uname': print(os.getenv('FAKE_OS','Linux')); sys.exit()
if name=='nvim':
    if args==['--version']: print('NVIM v'+os.getenv('FAKE_NVIM','0.12.6')); sys.exit()
    if os.getenv('FAKE_LAUNCH'): sys.exit(0)
    sys.exit('installer must not start Neovim with a config')
while args and args[0]=='-c': args=args[2:]
if args[0]=='ls-remote':
    assert args[-1]=='https://github.com/Boriska26/nvim-config'
    if os.getenv('FAKE_TAG_FAIL'): sys.exit(128)
    print(os.getenv('FAKE_TAGS',''),end=''); sys.exit()
assert args[0]=='clone'
assert args[-2]=='https://github.com/Boriska26/nvim-config'
destination=Path(args[-1]); destination.mkdir()
(destination/'partial').write_text('partial clone')
if os.getenv('FAKE_CLONE_FAIL'): sys.exit(128)
(destination/'init.lua').write_text('error("must not execute during installation")')
for path in ['lua/plugins/init.lua','lua/generators/init.lua','lua/devkit/help.lua']:
    p=destination/path; p.parent.mkdir(parents=True,exist_ok=True); p.write_text('-- fake')
if os.getenv('FAKE_RACE'):
    target=Path(os.environ['FAKE_RACE'])
    if os.getenv('FAKE_RACE_LINK'): target.symlink_to(os.environ['FAKE_RACE_LINK'],target_is_directory=True)
    else: target.mkdir(); (target/'user.txt').write_text('keep me')
'''

class Installers(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='devkit-install-test-')
        self.root = Path(self.temp.name)
        self.bin = self.root / 'tools'
        self.bin.mkdir()
        for name in ('nvim', 'git', 'uname'):
            p = self.bin / name
            p.write_text(FAKE)
            p.chmod(0o755)
        # Use a controlled PATH for missing-tool tests without depending on host nvim/git.
        for name in ('bash', 'mkdir', 'mktemp', 'rm', 'sort', 'tail', 'cut', 'mv', 'chmod', 'cat'):
            (self.bin / name).symlink_to(shutil.which(name))
        self.env = dict(os.environ, PATH=str(self.bin), HOME=str(self.root / 'home with spaces'),
                        XDG_CONFIG_HOME=str(self.root / 'config with spaces'), LANG='en_US.UTF-8',
                        LC_ALL='', LC_MESSAGES='', NVIM_APPNAME='another-config', FAKE_LOG=str(self.root/'calls'))
        for key in list(self.env):
            if key.startswith('FAKE_') and key != 'FAKE_LOG': del self.env[key]

    def tearDown(self): self.temp.cleanup()

    def invoke(self, *args, **changes):
        env = self.env | changes
        return subprocess.run([str(self.bin/'bash'), str(REPO/'install.sh'), *args], env=env,
                              text=True, capture_output=True, timeout=10)

    def target(self, name='nvim-devkit'): return Path(self.env['XDG_CONFIG_HOME']) / name

    def calls(self):
        p = self.root/'calls'
        return [json.loads(line) for line in p.read_text().splitlines()] if p.exists() else []

    def clean_stage(self):
        self.assertFalse(list(self.root.rglob('.nvim-devkit-install.*')))

    def test_default_and_launcher(self):
        main = self.target('nvim'); main.mkdir(parents=True); (main/'user.lua').write_text('original')
        result = self.invoke()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('installing main, not a stable release', result.stdout)
        self.assertTrue((self.target()/'init.lua').exists())
        self.assertEqual((main/'user.lua').read_text(), 'original')
        self.assertFalse((Path(self.env['HOME'])/'.bashrc').exists())
        self.assertTrue(all(args == ['--version'] for name,args,_ in self.calls() if name == 'nvim'))
        launch = self.target()/'.devkit-launch/nvim-devkit'
        run = subprocess.run([str(launch), 'file with spaces.txt'], env=self.env | {'FAKE_LAUNCH':'1'}, capture_output=True)
        self.assertEqual(run.returncode, 0)
        self.assertEqual(self.calls()[-1], ['nvim',['file with spaces.txt'],'nvim-devkit'])
        self.clean_stage()

    def test_main(self):
        result = self.invoke('--main')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue((self.target('nvim')/'init.lua').exists())
        self.assertFalse(self.target().exists())

    def test_main_existing_config(self):
        main = self.target('nvim')
        main.mkdir(parents=True)
        (main/'init.lua').write_text('-- user configuration')
        result = self.invoke('--main')
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('Path already exists', result.stderr)
        self.assertEqual((main/'init.lua').read_text(), '-- user configuration')
        self.assertFalse(any(name == 'git' for name, _, _ in self.calls()))
        self.clean_stage()

    def test_existing_types(self):
        for kind in ('directory', 'file', 'symlink', 'dangling'):
            with self.subTest(kind=kind):
                target = self.target(); target.parent.mkdir(parents=True, exist_ok=True)
                if kind == 'directory': target.mkdir()
                elif kind == 'file': target.write_text('keep')
                else: target.symlink_to(self.root/('home with spaces' if kind=='symlink' else 'missing'))
                result = self.invoke()
                self.assertNotEqual(result.returncode, 0)
                self.assertIn('Path already exists', result.stderr)
                self.assertFalse(any(name=='git' for name,_,_ in self.calls()))
                if kind=='directory': target.rmdir()
                else: target.unlink()
        self.clean_stage()

    def test_repeated_install(self):
        self.assertEqual(self.invoke().returncode, 0)
        before = (self.target()/'init.lua').read_bytes()
        result = self.invoke()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('already installed', result.stderr)
        self.assertEqual((self.target()/'init.lua').read_bytes(), before)

    def test_ref_selection(self):
        tags = ''.join('hash\trefs/tags/'+tag+'\n' for tag in ('v1.9.0','2.0.0','v1.10.0','v3.0.0-rc1','nightly'))
        result = self.invoke(FAKE_TAGS=tags)
        self.assertEqual(result.returncode, 0, result.stderr)
        clone = next(args for name,args,_ in self.calls() if name=='git' and 'clone' in args)
        self.assertEqual(clone[clone.index('--branch')+1], '2.0.0')

    def test_failures_clean_up(self):
        for option in ('FAKE_TAG_FAIL','FAKE_CLONE_FAIL'):
            with self.subTest(option=option):
                result = self.invoke(**{option:'1'})
                self.assertNotEqual(result.returncode, 0)
                self.assertFalse(self.target().exists())
                self.clean_stage()

    def test_concurrent_destination(self):
        result = self.invoke(FAKE_RACE=str(self.target()))
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual((self.target()/'user.txt').read_text(), 'keep me')
        self.clean_stage()

    def test_concurrent_symlink(self):
        outside = self.root/'outside'; outside.mkdir(); (outside/'user.txt').write_text('keep')
        result = self.invoke(FAKE_RACE=str(self.target()), FAKE_RACE_LINK=str(outside))
        self.assertNotEqual(result.returncode, 0)
        self.assertTrue(self.target().is_symlink())
        self.assertEqual((outside/'user.txt').read_text(), 'keep')
        self.clean_stage()

    def test_version_and_dependencies(self):
        result = self.invoke(FAKE_NVIM='0.12.5')
        self.assertNotEqual(result.returncode, 0); self.assertIn('0.12.6+', result.stderr)
        for name in ('nvim','git'):
            p=self.bin/name; p.rename(self.bin/(name+'.disabled'))
            result=self.invoke()
            self.assertNotEqual(result.returncode,0); self.assertIn('Install',result.stderr)
            (self.bin/(name+'.disabled')).rename(p)

    def test_platform_and_invalid_arguments(self):
        self.assertNotEqual(self.invoke(FAKE_OS='Darwin').returncode, 0)
        for flags in (('--unknown',),('--lang',),('--lang','xx'),('--main','--main'),('--lang','ru','--lang','en')):
            result=self.invoke(*flags)
            self.assertEqual(result.returncode,2); self.assertTrue('Usage:' in result.stderr or 'Использование:' in result.stderr)
        self.assertEqual(self.invoke('--help').returncode,0)
        self.assertIn('Использование',self.invoke('--help',LANG='ru_RU.UTF-8').stdout)
        self.assertIn('Usage:',self.invoke('--lang','en','--help',LANG='ru_RU.UTF-8').stdout)

    def test_default_home_and_relative_xdg(self):
        result=self.invoke(XDG_CONFIG_HOME='')
        self.assertEqual(result.returncode,0,result.stderr)
        self.assertTrue((Path(self.env['HOME'])/'.config/nvim-devkit/init.lua').exists())
        self.assertNotEqual(self.invoke(XDG_CONFIG_HOME='relative').returncode,0)

class PowerShellSyntax(unittest.TestCase):
    @unittest.skipUnless(shutil.which('pwsh') or shutil.which('powershell'), 'PowerShell is not installed')
    def test_parser(self):
        # Parse only: do not install anything or change the host environment.
        engine = shutil.which('pwsh') or shutil.which('powershell')
        code = '''$tokens = $null; $errors = $null
[void][System.Management.Automation.Language.Parser]::ParseFile(
    $env:DEVKIT_PS_SCRIPT, [ref]$tokens, [ref]$errors)
if ($errors.Count) { $errors | Out-String | Write-Host; exit 1 }
exit 0'''
        result = subprocess.run([engine, '-NoProfile', '-NonInteractive', '-Command', code],
                                env=os.environ | {'DEVKIT_PS_SCRIPT': str(REPO/'install.ps1')},
                                capture_output=True, text=True, timeout=30)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

if __name__ == '__main__': unittest.main()
