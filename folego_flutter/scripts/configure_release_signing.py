#!/usr/bin/env python3
"""Configure signing only inside a GENERATED Android scaffold on an ephemeral runner.

The long-lived upload keystore must come from a secure secret; never commit
android/key.properties, the keystore, or a locally generated Gradle patch.
"""
from __future__ import annotations

import sys
from pathlib import Path


def configure_kotlin(text: str) -> str:
    if "signingConfigs.getByName(\"release\")" in text:
        raise ValueError("An existing release signing config needs manual review")
    debug_line = 'signingConfig = signingConfigs.getByName("debug")'
    if text.count(debug_line) != 1 or text.count("    buildTypes {") != 1:
        raise ValueError("Generated Kotlin Gradle template has changed; refusing unsafe patch")
    if text.count("android {") != 1:
        raise ValueError("Missing Android DSL block in generated Gradle template")

    imports = "import java.io.FileInputStream\nimport java.util.Properties\n\n"
    properties = (
        "val folegoKeystoreProperties = Properties()\n"
        'val folegoKeystoreFile = rootProject.file("key.properties")\n'
        "if (!folegoKeystoreFile.isFile) error(\"Missing Android upload signing properties\")\n"
        "folegoKeystoreProperties.load(FileInputStream(folegoKeystoreFile))\n\n"
    )
    signing = (
        "    signingConfigs {\n"
        '        create("release") {\n'
        '            keyAlias = folegoKeystoreProperties.getProperty("keyAlias")\n'
        '            keyPassword = folegoKeystoreProperties.getProperty("keyPassword")\n'
        '            storeFile = file(folegoKeystoreProperties.getProperty("storeFile"))\n'
        '            storePassword = folegoKeystoreProperties.getProperty("storePassword")\n'
        "        }\n"
        "    }\n"
    )
    return (
        imports
        + text.replace("android {", properties + "android {", 1)
            .replace("    buildTypes {", signing + "    buildTypes {", 1)
            .replace(debug_line, 'signingConfig = signingConfigs.getByName("release")', 1)
    )


def configure_groovy(text: str) -> str:
    if "signingConfig signingConfigs.release" in text:
        raise ValueError("An existing Groovy release signing config needs manual review")
    debug_line = "signingConfig signingConfigs.debug"
    if text.count(debug_line) != 1 or text.count("    buildTypes {") != 1:
        raise ValueError("Generated Groovy Gradle template has changed; refusing unsafe patch")
    if text.count("android {") != 1:
        raise ValueError("Missing Android DSL block in generated Gradle template")

    imports = "import java.util.Properties\nimport java.io.FileInputStream\n\n"
    properties = (
        "def folegoKeystoreProperties = new Properties()\n"
        "def folegoKeystoreFile = rootProject.file('key.properties')\n"
        "if (!folegoKeystoreFile.isFile()) throw new GradleException('Missing Android signing properties')\n"
        "folegoKeystoreProperties.load(new FileInputStream(folegoKeystoreFile))\n\n"
    )
    signing = (
        "    signingConfigs {\n"
        "        release {\n"
        "            keyAlias folegoKeystoreProperties['keyAlias']\n"
        "            keyPassword folegoKeystoreProperties['keyPassword']\n"
        "            storeFile file(folegoKeystoreProperties['storeFile'])\n"
        "            storePassword folegoKeystoreProperties['storePassword']\n"
        "        }\n"
        "    }\n"
    )
    return (
        imports
        + text.replace("android {", properties + "android {", 1)
            .replace("    buildTypes {", signing + "    buildTypes {", 1)
            .replace(debug_line, "signingConfig signingConfigs.release", 1)
    )


def main(project_dir: Path) -> None:
    android = project_dir / "android" / "app"
    kts, groovy = android / "build.gradle.kts", android / "build.gradle"
    if kts.exists():
        path, configure = kts, configure_kotlin
    elif groovy.exists():
        path, configure = groovy, configure_groovy
    else:
        raise FileNotFoundError("Expected an existing generated Android Gradle file")

    path.write_text(configure(path.read_text()))
    print("Generated Android project configured for upload-key signing")


if __name__ == "__main__":
    if len(sys.argv) != 2:
        raise SystemExit("Usage: configure_release_signing.py <flutter-project-directory>")
    main(Path(sys.argv[1]).resolve())
