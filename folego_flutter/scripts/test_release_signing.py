"""No secrets required: validate signing-patch behavior against Flutter templates."""
import importlib.util
import tempfile
import unittest
from pathlib import Path

SCRIPT = Path(__file__).with_name("configure_release_signing.py")
spec = importlib.util.spec_from_file_location("folego_release_signing", SCRIPT)
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class SigningConfigTests(unittest.TestCase):
    def test_kotlin_template(self):
        original = (
            "plugins { id(\"com.android.application\") }\n"
            "android {\n"
            "    defaultConfig { applicationId = \"com.caueccipriano.folego\" }\n"
            "    buildTypes {\n"
            "        release {\n"
            "            signingConfig = signingConfigs.getByName(\"debug\")\n"
            "        }\n"
            "    }\n"
            "}\n"
        )
        patched = module.configure_kotlin(original)
        self.assertIn('create("release")', patched)
        self.assertIn('rootProject.file("key.properties")', patched)
        self.assertIn('signingConfig = signingConfigs.getByName("release")', patched)
        self.assertNotIn('signingConfig = signingConfigs.getByName("debug")', patched)
        with self.assertRaises(ValueError):
            module.configure_kotlin(patched)

    def test_groovy_template(self):
        original = (
            "plugins { id 'com.android.application' }\n"
            "android {\n"
            "    buildTypes { release {\n"
            "        signingConfig signingConfigs.debug\n"
            "    }}\n"
            "}\n"
        )
        patched = module.configure_groovy(original)
        self.assertIn("rootProject.file('key.properties')", patched)
        self.assertIn("signingConfig signingConfigs.release", patched)
        self.assertNotIn("signingConfig signingConfigs.debug", patched)

    def test_fail_closed_on_changed_template(self):
        with self.assertRaises(ValueError):
            module.configure_kotlin("android { buildTypes { } }")

    def test_generated_android_path(self):
        with tempfile.TemporaryDirectory() as temp:
            path = Path(temp) / "android" / "app"
            path.mkdir(parents=True)
            target = path / "build.gradle.kts"
            target.write_text(
                'android {\n    buildTypes {\n'
                '        release { signingConfig = signingConfigs.getByName("debug") }\n'
                '    }\n}'
            )
            module.main(Path(temp))
            self.assertIn('getByName("release")', target.read_text())


if __name__ == "__main__":
    unittest.main()
