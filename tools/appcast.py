#!/usr/bin/env python3
"""Adds or replaces one release in a Sparkle appcast. release-app.sh calls it; see docs/updates.md.

  appcast.py APPCAST --title Pier --link https://newitools.app/pier/ --version 2 --short 0.1.1 \
      --min-system 26.0 --url https://.../Pier-0.1.1.dmg --length 123 --signature BASE64 \
      [--notes-url URL] [--notes TEXT]
  appcast.py --self-check

The newest release goes first; an item with the same build number (sparkle:version) is replaced.
"""
import argparse
import email.utils
import os
import sys
import tempfile
import xml.etree.ElementTree as ET

SPARKLE = "http://www.andymatuschak.org/xml-namespaces/sparkle"
ET.register_namespace("sparkle", SPARKLE)
S = "{%s}" % SPARKLE


def update(path, a, now=None):
    if os.path.exists(path):
        tree = ET.parse(path)
        channel = tree.getroot().find("channel")
    else:
        rss = ET.Element("rss", {"version": "2.0"})
        channel = ET.SubElement(rss, "channel")
        ET.SubElement(channel, "title").text = a.title
        ET.SubElement(channel, "link").text = a.link
        tree = ET.ElementTree(rss)

    for old in channel.findall("item"):
        if old.findtext(S + "version") == a.version:
            channel.remove(old)

    item = ET.Element("item")
    ET.SubElement(item, "title").text = "Version " + a.short
    ET.SubElement(item, "pubDate").text = email.utils.formatdate(now, usegmt=True)
    ET.SubElement(item, S + "version").text = a.version
    ET.SubElement(item, S + "shortVersionString").text = a.short
    ET.SubElement(item, S + "minimumSystemVersion").text = a.min_system
    if a.notes_url:
        ET.SubElement(item, S + "releaseNotesLink").text = a.notes_url
    if a.notes:
        ET.SubElement(item, "description").text = a.notes
    ET.SubElement(item, "enclosure", {"url": a.url, "length": str(a.length), "type": "application/octet-stream",
                                      S + "edSignature": a.signature})

    first = next((i for i, child in enumerate(channel) if child.tag == "item"), len(channel))
    channel.insert(first, item)
    ET.indent(tree, space="  ")
    tmp = path + ".tmp"
    tree.write(tmp, encoding="utf-8", xml_declaration=True)
    os.replace(tmp, path)


def parser():
    p = argparse.ArgumentParser()
    p.add_argument("appcast", nargs="?")
    p.add_argument("--self-check", action="store_true")
    for name in ("title", "link", "version", "short", "min-system", "url", "length", "signature"):
        p.add_argument("--" + name)
    p.add_argument("--notes-url")
    p.add_argument("--notes")
    return p


def self_check():
    with tempfile.TemporaryDirectory() as d:
        path = os.path.join(d, "appcast.xml")
        base = ["--title", "Demo", "--link", "https://example.com/demo/", "--min-system", "26.0",
                "--length", "10", "--signature", "c2ln"]
        def run(version, short, *extra):
            update(path, parser().parse_args([path, "--version", version, "--short", short,
                                              "--url", f"https://example.com/Demo-{short}.dmg", *base, *extra]))
        run("1", "0.1.0")
        run("2", "0.1.1", "--notes-url", "https://example.com/notes")
        run("2", "0.1.1")   # re-releasing a build replaces it
        items = ET.parse(path).getroot().find("channel").findall("item")
        assert [i.findtext(S + "version") for i in items] == ["2", "1"], "newest first, no duplicate"
        assert items[0].find(S + "releaseNotesLink") is None, "replaced item drops the old notes"
        enclosure = items[0].find("enclosure")
        assert enclosure.get(S + "edSignature") == "c2ln" and enclosure.get("length") == "10"
        assert items[1].findtext(S + "minimumSystemVersion") == "26.0"
        assert ET.parse(path).getroot().findtext("channel/title") == "Demo"
    print("appcast self-check ok")


if __name__ == "__main__":
    args = parser().parse_args()
    if args.self_check:
        self_check()
        sys.exit(0)
    missing = [n for n in ("appcast", "title", "link", "version", "short", "min_system", "url", "length", "signature")
               if not getattr(args, n)]
    if missing:
        sys.exit("appcast.py: missing " + ", ".join(missing))
    update(args.appcast, args)
