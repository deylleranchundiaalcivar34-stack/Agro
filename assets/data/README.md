# Ecuador administrative division catalog

`ecuador_administrative_divisions.json` contains 24 provinces and 223 cantons. The original 221 names and reference coordinates are distributed by [Open Admin Data](https://github.com/open-admin-data/ecuador-administrative-divisions) under CC BY 4.0. The two cantons added in the 2026 boundary release use a bounding-box center only to move the map preview; the names and DPA codes come from the boundary source. The original names were checked against the [INEC 2026 classifier](https://aplicaciones2.ecuadorencifras.gob.ec/SIN/descargas/cge2026.pdf), updated through December 31, 2025.

The source omits coordinates for Juján and Coronel Marcelino Maridueña. Their reference map centers are filled from [GeoNames](https://www.geonames.org/3660333/) and [GeoDatos](https://www.geodatos.net/coordenadas/ecuador/coronel-marcelino-mariduena), respectively. These coordinates are only used to center a map preview/filter and do not replace the producer's manually selected approximate point.

The source file identifies its CC BY 4.0 license and update date. Refresh this bundled data from its source when the administrative classifier changes.

`ecuador_canton_boundaries.json` contains low-resolution WGS84 canton polygons from the [geoecu datos-v0.3.0 release](https://github.com/f-slg/geoecu/releases/tag/datos-v0.3.0), derived from CONALI/Ministry of Government open data under CC BY. The asset is delta-encoded by `scripts/convert_ecuador_canton_boundaries.py`. Agro+ uses it locally to suggest province and canton from the rounded point the user taps on the map. These reference boundaries are not a legal determination of jurisdiction.
