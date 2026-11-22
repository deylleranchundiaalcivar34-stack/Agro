"""Convert the CONALI low-resolution GeoPackage for Agro+ offline lookup.

Source release: geoecu datos-v0.3.0, derived from CONALI/Ministerio de Gobierno
open data under CC BY. The output keeps canton polygon rings at 1e-5 degree
precision and delta-encodes coordinates to keep the Flutter asset compact.
"""

from __future__ import annotations

import argparse
import json
import sqlite3
import struct
from pathlib import Path
from typing import Any


SCALE = 100_000
SOURCE_DATE = "2026-07-17"
SOURCE_NAME = "CONALI, Ministerio de Gobierno del Ecuador; geoecu datos-v0.3.0"


def read_uint32(data: bytes, offset: int, endian: str) -> tuple[int, int]:
    return struct.unpack_from(f"{endian}I", data, offset)[0], offset + 4


def read_double(data: bytes, offset: int, endian: str) -> tuple[float, int]:
    return struct.unpack_from(f"{endian}d", data, offset)[0], offset + 8


def parse_wkb(data: bytes, offset: int = 0) -> tuple[list[list[list[tuple[float, float]]]], int]:
    byte_order = data[offset]
    endian = "<" if byte_order == 1 else ">"
    offset += 1
    geometry_type, offset = read_uint32(data, offset, endian)
    geometry_type %= 1000

    if geometry_type == 6:  # MultiPolygon
        polygon_count, offset = read_uint32(data, offset, endian)
        polygons = []
        for _ in range(polygon_count):
            polygon, offset = parse_wkb(data, offset)
            if len(polygon) != 1:
                raise ValueError("Expected a polygon inside MultiPolygon.")
            polygons.extend(polygon)
        return polygons, offset

    if geometry_type != 3:  # Polygon
        raise ValueError(f"Unsupported WKB geometry type: {geometry_type}")

    ring_count, offset = read_uint32(data, offset, endian)
    rings = []
    for _ in range(ring_count):
        point_count, offset = read_uint32(data, offset, endian)
        ring = []
        for _ in range(point_count):
            longitude, offset = read_double(data, offset, endian)
            latitude, offset = read_double(data, offset, endian)
            ring.append((longitude, latitude))
        rings.append(ring)
    return [rings], offset


def decode_gpkg_geometry(blob: bytes) -> list[list[list[tuple[float, float]]]]:
    if blob[:2] != b"GP" or len(blob) < 8:
        raise ValueError("Invalid GeoPackage geometry header.")
    flags = blob[3]
    endian = "<" if flags & 1 else ">"
    srs_id = struct.unpack_from(f"{endian}i", blob, 4)[0]
    if srs_id != 4326:
        raise ValueError(f"Expected WGS84 (EPSG:4326), found EPSG:{srs_id}.")
    envelope_type = (flags >> 1) & 0b111
    envelope_sizes = {0: 0, 1: 32, 2: 48, 3: 48, 4: 64}
    if envelope_type not in envelope_sizes:
        raise ValueError(f"Invalid GeoPackage envelope type: {envelope_type}")
    polygons, _ = parse_wkb(blob, 8 + envelope_sizes[envelope_type])
    return polygons


def encode_ring(ring: list[tuple[float, float]]) -> list[int]:
    encoded: list[int] = []
    previous_longitude = 0
    previous_latitude = 0
    for index, (longitude, latitude) in enumerate(ring):
        current_longitude = round(longitude * SCALE)
        current_latitude = round(latitude * SCALE)
        if index == 0:
            encoded.extend((current_longitude, current_latitude))
        else:
            encoded.extend(
                (
                    current_longitude - previous_longitude,
                    current_latitude - previous_latitude,
                )
            )
        previous_longitude = current_longitude
        previous_latitude = current_latitude
    return encoded


def ring_bounds(rings: list[list[tuple[float, float]]]) -> list[int]:
    points = [point for ring in rings for point in ring]
    return [
        round(min(point[0] for point in points) * SCALE),
        round(min(point[1] for point in points) * SCALE),
        round(max(point[0] for point in points) * SCALE),
        round(max(point[1] for point in points) * SCALE),
    ]


def display_name(name: str) -> str:
    return " ".join(part.capitalize() for part in name.lower().split())


def convert(gpkg_path: Path, boundary_path: Path, catalog_path: Path) -> None:
    connection = sqlite3.connect(gpkg_path)
    try:
        rows = connection.execute(
            """select geom, dpa_canton, canton, dpa_provin, provincia
               from cantones where tipo = ? order by dpa_canton""",
            ("cantón",),
        ).fetchall()
    finally:
        connection.close()

    if not rows:
        raise ValueError("The GeoPackage contains no canton polygons.")

    features: list[dict[str, Any]] = []
    new_catalog_entries: list[tuple[str, str, str, float, float]] = []
    seen_codes: set[str] = set()
    for geometry, canton_code, canton, province_code, province in rows:
        canton_code = f"EC{canton_code}"
        province_code = f"EC{province_code}"
        if canton_code in seen_codes:
            raise ValueError(f"Duplicate canton code: {canton_code}")
        seen_codes.add(canton_code)

        polygons = decode_gpkg_geometry(geometry)
        feature_polygons = []
        bounds_points = []
        for rings in polygons:
            if not rings or any(len(ring) < 4 for ring in rings):
                raise ValueError(f"Invalid polygon rings for {canton_code}")
            bounds_points.extend(point for ring in rings for point in ring)
            feature_polygons.append(
                {
                    "bbox": ring_bounds(rings),
                    "rings": [encode_ring(ring) for ring in rings],
                }
            )
        features.append(
            {
                "code": canton_code,
                "province_code": province_code,
                "polygons": feature_polygons,
            }
        )
        new_catalog_entries.append(
            (
                canton_code,
                province_code,
                display_name(canton),
                (min(point[1] for point in bounds_points)
                 + max(point[1] for point in bounds_points))
                / 2,
                (min(point[0] for point in bounds_points)
                 + max(point[0] for point in bounds_points))
                / 2,
            )
        )

    catalog = json.loads(catalog_path.read_text(encoding="utf-8"))
    provinces = {province["code"]: province for province in catalog["provinces"]}
    known_cantons = {
        canton["code"]
        for province in catalog["provinces"]
        for canton in province["cantons"]
    }
    for code, province_code, name, latitude, longitude in new_catalog_entries:
        if code in known_cantons:
            continue
        province = provinces.get(province_code)
        if province is None:
            raise ValueError(f"Province {province_code} missing from the catalog.")
        province["cantons"].append(
            {
                "code": code,
                "name": name,
                "latitude": round(latitude, 6),
                "longitude": round(longitude, 6),
            }
        )
        province["cantons"].sort(key=lambda item: item["name"].casefold())

    boundary_data = {
        "source": SOURCE_NAME,
        "source_date": SOURCE_DATE,
        "license": "CC BY",
        "coordinate_scale": SCALE,
        "features": features,
    }
    boundary_path.parent.mkdir(parents=True, exist_ok=True)
    boundary_path.write_text(
        json.dumps(boundary_data, ensure_ascii=False, separators=(",", ":"))
        + "\n",
        encoding="utf-8",
    )
    catalog_path.write_text(
        json.dumps(catalog, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    print(f"Wrote {len(features)} canton boundaries to {boundary_path}.")
    print(f"Added {len(seen_codes - known_cantons)} new catalog entries.")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--gpkg", required=True, type=Path)
    parser.add_argument("--boundaries", required=True, type=Path)
    parser.add_argument("--catalog", required=True, type=Path)
    args = parser.parse_args()
    convert(args.gpkg, args.boundaries, args.catalog)


if __name__ == "__main__":
    main()
