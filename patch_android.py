#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
يعدّل مشروع Android الذي يولّده `flutter create` بحيث:
  1) يضيف كل أذونات الإشعارات والمنبّهات الدقيقة والموقع.
  2) يسجّل مستقبلات flutter_local_notifications (إعادة الجدولة بعد إعادة التشغيل).
  3) يضبط اسم التطبيق الظاهر إلى "مجاهد".
  4) يفعّل core library desugaring المطلوب للإشعارات المجدولة.
  5) يضبط gradle.properties.
يتعامل مع Groovy (build.gradle) و Kotlin DSL (build.gradle.kts).

الاستخدام: python3 patch_android.py <project-dir>
"""

import os
import re
import sys

PERMISSIONS = [
    "android.permission.INTERNET",
    "android.permission.POST_NOTIFICATIONS",
    "android.permission.RECEIVE_BOOT_COMPLETED",
    "android.permission.SCHEDULE_EXACT_ALARM",
    "android.permission.USE_EXACT_ALARM",
    "android.permission.VIBRATE",
    "android.permission.ACCESS_COARSE_LOCATION",
    "android.permission.ACCESS_FINE_LOCATION",
]

RECEIVERS = """
        <receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver" />
        <receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver">
            <intent-filter>
                <action android:name="android.intent.action.BOOT_COMPLETED"/>
                <action android:name="android.intent.action.MY_PACKAGE_REPLACED"/>
                <action android:name="android.intent.action.QUICKBOOT_POWERON" />
                <action android:name="com.htc.intent.action.QUICKBOOT_POWERON"/>
            </intent-filter>
        </receiver>
"""

DESUGAR_VERSION = "2.1.4"


def log(msg):
    print("[patch_android] " + msg)


def patch_manifest(root):
    path = os.path.join(root, "android", "app", "src", "main", "AndroidManifest.xml")
    if not os.path.exists(path):
        log("WARNING: manifest not found at " + path)
        return
    with open(path, encoding="utf-8") as fh:
        xml = fh.read()

    missing = [p for p in PERMISSIONS if p not in xml]
    if missing:
        block = "\n".join(
            '    <uses-permission android:name="%s"/>' % p for p in missing
        )
        idx = xml.find("<application")
        if idx == -1:
            log("WARNING: <application> not found, appending permissions at end")
            xml = xml.replace("</manifest>", block + "\n</manifest>", 1)
        else:
            xml = xml[:idx] + block + "\n\n    " + xml[idx:]
        log("added %d permission(s)" % len(missing))

    if "ScheduledNotificationReceiver" not in xml:
        xml = xml.replace("</application>", RECEIVERS + "    </application>", 1)
        log("registered notification receivers")

    # اسم التطبيق الظاهر
    if 'android:label=' in xml:
        xml = re.sub(r'android:label="[^"]*"', 'android:label="مجاهد"', xml, count=1)

    with open(path, "w", encoding="utf-8") as fh:
        fh.write(xml)
    log("manifest patched")


def patch_gradle(root):
    app_dir = os.path.join(root, "android", "app")
    kts = os.path.join(app_dir, "build.gradle.kts")
    groovy = os.path.join(app_dir, "build.gradle")

    if os.path.exists(kts):
        path, kotlin = kts, True
    elif os.path.exists(groovy):
        path, kotlin = groovy, False
    else:
        log("WARNING: no app-level gradle file found")
        return

    with open(path, encoding="utf-8") as fh:
        g = fh.read()

    already = ("isCoreLibraryDesugaringEnabled" in g) or ("coreLibraryDesugaringEnabled" in g)

    if not already:
        if kotlin:
            extra = """
android {
    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:%s")
}
""" % DESUGAR_VERSION
        else:
            extra = """
android {
    compileOptions {
        coreLibraryDesugaringEnabled true
        sourceCompatibility JavaVersion.VERSION_17
        targetCompatibility JavaVersion.VERSION_17
    }
}

dependencies {
    coreLibraryDesugaring 'com.android.tools:desugar_jdk_libs:%s'
}
""" % DESUGAR_VERSION
        g = g.rstrip() + "\n" + extra
        log("enabled core library desugaring in " + os.path.basename(path))
    else:
        log("desugaring already enabled")

    with open(path, "w", encoding="utf-8") as fh:
        fh.write(g)


def patch_gradle_properties(root):
    path = os.path.join(root, "android", "gradle.properties")
    wanted = {
        "android.useAndroidX": "true",
        "org.gradle.jvmargs": "-Xmx4G -XX:MaxMetaspaceSize=2G -XX:+HeapDumpOnOutOfMemoryError",
    }
    lines = []
    if os.path.exists(path):
        with open(path, encoding="utf-8") as fh:
            lines = fh.read().splitlines()

    keys = set()
    for i, line in enumerate(lines):
        stripped = line.strip()
        if not stripped or stripped.startswith("#") or "=" not in stripped:
            continue
        key = stripped.split("=", 1)[0].strip()
        keys.add(key)
        if key in wanted:
            lines[i] = "%s=%s" % (key, wanted[key])
            del wanted[key]

    for key, value in wanted.items():
        lines.append("%s=%s" % (key, value))

    with open(path, "w", encoding="utf-8") as fh:
        fh.write("\n".join(lines) + "\n")
    log("gradle.properties patched")


def main():
    root = sys.argv[1] if len(sys.argv) > 1 else "app"
    log("patching " + os.path.abspath(root))
    patch_manifest(root)
    patch_gradle(root)
    patch_gradle_properties(root)
    log("done")


if __name__ == "__main__":
    main()
