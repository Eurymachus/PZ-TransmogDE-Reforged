import os
import re
import uuid
import xml.etree.ElementTree as ET
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
PZ_ROOT = Path(os.environ.get("PZ_ROOT", r"C:\Games\Steam\steamapps\common\ProjectZomboid"))
VERSION_ROOT = ROOT / "Contents" / "mods" / "Better Dressed" / "42.19"
MEDIA_ROOT = VERSION_ROOT / "media"
SCRIPTS_ROOT = PZ_ROOT / "media" / "scripts"
CLOTHING_ROOT = PZ_ROOT / "media" / "clothing" / "clothingItems"
OUT_CLOTHING_ROOT = MEDIA_ROOT / "clothing" / "clothingItems"
OUT_SCRIPT = MEDIA_ROOT / "scripts" / "TransmogAltItems.txt"
OUT_LUA = MEDIA_ROOT / "lua" / "shared" / "Transmog" / "GeneratedAltItems.lua"
GUID_TABLE = MEDIA_ROOT / "fileGuidTable.xml"


def find_blocks(text, keyword):
    pattern = re.compile(r"\b" + re.escape(keyword) + r"\s+([^\s{]+)\s*\{")
    for match in pattern.finditer(text):
        name = match.group(1)
        start = match.end()
        depth = 1
        i = start
        while i < len(text) and depth:
            if text[i] == "{":
                depth += 1
            elif text[i] == "}":
                depth -= 1
            i += 1
        yield name, text[start : i - 1]


def get_param(block, name):
    match = re.search(r"\b" + re.escape(name) + r"\s*=\s*([^,\s]+)", block)
    return match.group(1) if match else None


def iter_script_clothing_items():
    for path in SCRIPTS_ROOT.rglob("*.txt"):
        text = path.read_text(encoding="utf-8", errors="ignore")
        for module_name, module_block in find_blocks(text, "module"):
            for item_name, item_block in find_blocks(module_block, "item"):
                item_type = (get_param(item_block, "ItemType") or "").lower()
                clothing_item = get_param(item_block, "ClothingItem")
                body_location = get_param(item_block, "BodyLocation")
                if "clothing" in item_type and clothing_item and body_location:
                    yield {
                        "full_type": f"{module_name}.{item_name}",
                        "script_name": item_name,
                        "clothing_item": clothing_item,
                        "body_location": body_location,
                    }


def text_or_empty(root, name):
    value = root.findtext(name)
    return "" if value is None else value.strip()


def has_real_alt(root):
    alt_male = text_or_empty(root, "m_AltMaleModel")
    alt_female = text_or_empty(root, "m_AltFemaleModel")
    return (
        bool(alt_male)
        and bool(alt_female)
        and alt_male.lower() != "null"
        and alt_female.lower() != "null"
    )


def write_xml(path, source_root, guid):
    alt_male = text_or_empty(source_root, "m_AltMaleModel")
    alt_female = text_or_empty(source_root, "m_AltFemaleModel")
    source_root.find("m_MaleModel").text = alt_male
    source_root.find("m_FemaleModel").text = alt_female

    for tag in ("m_AltMaleModel", "m_AltFemaleModel"):
        elem = source_root.find(tag)
        if elem is not None:
            elem.text = ""

    guid_elem = source_root.find("m_GUID")
    if guid_elem is None:
        guid_elem = ET.SubElement(source_root, "m_GUID")
    guid_elem.text = guid

    tree = ET.ElementTree(source_root)
    ET.indent(tree, space="  ")
    tree.write(path, encoding="utf-8", xml_declaration=True)


def sanitize(full_type):
    return re.sub(r"[^A-Za-z0-9_]", "_", full_type)


def generate():
    OUT_CLOTHING_ROOT.mkdir(parents=True, exist_ok=True)

    for path in OUT_CLOTHING_ROOT.glob("TransmogAltItem_*.xml"):
        path.unlink()

    entries = []
    for item in iter_script_clothing_items():
        xml_path = CLOTHING_ROOT / f"{item['clothing_item']}.xml"
        if not xml_path.exists():
            continue
        try:
            root = ET.parse(xml_path).getroot()
        except ET.ParseError:
            continue
        if has_real_alt(root):
            entries.append((item, xml_path))

    entries.sort(key=lambda entry: entry[0]["full_type"].lower())

    script_lines = ["module TransmogDE {", "    imports { Base }", ""]
    lua_lines = [
        "TransmogDE = TransmogDE or {}",
        "TransmogDE.AltTransmogItems = TransmogDE.AltTransmogItems or {}",
        "",
    ]
    guid_entries = []

    for index, (item, xml_path) in enumerate(entries, start=1):
        alt_name = f"TransmogAltItem_{index}_{sanitize(item['full_type'])}"
        full_alt_name = f"TransmogDE.{alt_name}"
        guid = str(uuid.uuid5(uuid.NAMESPACE_URL, f"BetterDressed/42.19/{alt_name}"))

        root = ET.parse(xml_path).getroot()
        write_xml(OUT_CLOTHING_ROOT / f"{alt_name}.xml", root, guid)
        guid_entries.append((f"media/clothing/clothingItems/{alt_name}.xml", guid))

        script_lines.extend(
            [
                f"    item {alt_name}",
                "    {",
                "        ItemType = base:clothing,",
                "        DisplayCategory = Transmog,",
                "        Weight = 0,",
                "        Hidden = TRUE,",
                "        Cosmetic = TRUE,",
                f"        /* DisplayName = {alt_name}, */",
                "        Icon = TransmogItem,",
                "        BodyLocation = TransmogDE:Transmog_Location,",
                f"        ClothingItem = {alt_name},",
                "    }",
                "",
            ]
        )

        lua_lines.append(f'TransmogDE.AltTransmogItems["{item["full_type"]}"] = "{full_alt_name}"')

    script_lines.append("}")
    OUT_SCRIPT.write_text("\n".join(script_lines) + "\n", encoding="utf-8")
    OUT_LUA.write_text("\n".join(lua_lines) + "\n", encoding="utf-8")
    update_guid_table(guid_entries)
    print(f"Generated {len(entries)} alt transmog carriers")


def update_guid_table(guid_entries):
    text = remove_existing_alt_guid_entries(GUID_TABLE.read_text(encoding="utf-8"))
    insert = []
    for path, guid in guid_entries:
        insert.extend(
            [
                "",
                "  <files>",
                f"    <path>{path}</path>",
                f"    <guid>{guid}</guid>",
                "  </files>",
            ]
        )
    replacement = "\n".join(insert) + "\n\n</fileGuidTable>"
    text = text.replace("\n</fileGuidTable>", replacement)
    GUID_TABLE.write_text(text, encoding="utf-8")


def remove_existing_alt_guid_entries(text):
    blocks = re.split(r"(\s*<files>\s*.*?\s*</files>)", text, flags=re.S)
    kept = []
    for block in blocks:
        if "media/clothing/clothingItems/TransmogAltItem_" in block:
            continue
        kept.append(block)
    return "".join(kept)


if __name__ == "__main__":
    generate()
