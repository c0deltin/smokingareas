# Manually downloaded open data

Some official datasets are only reachable from within Japan (the servers
refuse connections from abroad, including GitHub Actions runners). They are
downloaded manually and kept here unchanged; `update_opendata.py` reads them
like any other source.

| File | Dataset | Publisher / licence | Downloaded |
|---|---|---|---|
| `okayama_public_toilets.tsv` | 公衆トイレ (public toilets), おかやま全県統合型GIS, <https://www.gis.pref.okayama.jp/pref-okayama/OpenDataDetail?lid=1442> | City of Okayama (岡山市), CC BY | 2026-11-10 |

To update a file: open the URL from a device in Japan, download the CSV
("公衆トイレ【csv】" → ダウンロード), replace the file without editing it, and
run `python3 tool/opendata/update_opendata.py okayama_toilets`.
