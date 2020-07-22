# Bibliotheca Hauptverarbeitung
# - Datenbereinigungen
# - Mapping auf PICA3
# - PICA3-Spalten als CSV (via Template) exportieren

# ================================== CONFIG ================================== #

# TSV-Exporte aller Einzelprojekte in ein Zip-Archiv packen
zip -j "${workspace}/bibliotheca.zip" \
  "${workspace}/bautzen.tsv" \
  "${workspace}/breitenbrunn.tsv" \
  "${workspace}/dresden.tsv" \
  "${workspace}/glauchau.tsv" \
  "${workspace}/plauen.tsv"

projects["bibliotheca"]="${workspace}/bibliotheca.zip"

# ================================= STARTUP ================================== #

refine_start; echo

# ================================== IMPORT ================================== #

# Neues Projekt erstellen aus Zip-Archiv

p="bibliotheca"
echo "import file" "${projects[$p]}" "..."
if curl -fs --write-out "%{redirect_url}\n" \
  --form project-file="@${projects[$p]}" \
  --form project-name="${p}" \
  --form format="text/line-based/*sv" \
  --form options='{
                   "encoding": "UTF-8",
                   "includeFileSources": "true",
                   "separator": "\t"
                  }' \
  "${endpoint}/command/core/create-project-from-upload$(refine_csrf)" \
  > "${workspace}/${p}.id"
then
  log "imported ${projects[$p]} as ${p}"
else
  error "import of ${projects[$p]} failed!"
fi
refine_store "${p}" "${workspace}/${p}.id" || error "import of ${p} failed!"
echo

# ================================ TRANSFORM ================================= #

# --------------------------- 01 Spalten sortieren --------------------------- #

# damit Records-Mode erhalten bleibt
# - M|MEDGR > Facet > Text facet > eBook
# -- show as: records
# --- All > Edit rows > Remove all matching rows

echo "Spalten sortieren: Beginnen mit 1. M|MEDNR, 2. E|EXNR, 3. File"
if curl -fs \
  --data project="${projects[$p]}" \
  --data-urlencode "operations@-" \
  "${endpoint}/command/core/apply-operations$(refine_csrf)" > /dev/null \
  << "JSON"
  [
    {
      "op": "core/column-move",
      "columnName": "File",
      "index": 0,
      "description": "Move column File to position 0"
    },
    {
      "op": "core/column-move",
      "columnName": "E|EXNR",
      "index": 0,
      "description": "Move column E|EXNR to position 0"
    },
    {
      "op": "core/column-move",
      "columnName": "M|MEDNR",
      "index": 0,
      "description": "Move column M|MEDNR to position 0"
    }
  ]
JSON
then
  log "transformed ${p} (${projects[$p]})"
else
  error "transform ${p} (${projects[$p]}) failed!"
fi
echo

# ----------------------- 02 E-Books löschen (Bautzen) ----------------------- #

# spec_Z_01
# - M|MEDGR > Facet > Text facet > eBook
# -- show as: records
# --- All > Edit rows > Remove all matching rows

echo "E-Books löschen (Bautzen)..."
if curl -fs \
  --data project="${projects[$p]}" \
  --data-urlencode "operations@-" \
  "${endpoint}/command/core/apply-operations$(refine_csrf)" > /dev/null \
  << "JSON"
  [
    {
      "op": "core/row-removal",
      "engineConfig": {
        "facets": [
          {
            "type": "list",
            "name": "M|MEDGR",
            "expression": "value",
            "columnName": "M|MEDGR",
            "invert": false,
            "omitBlank": false,
            "omitError": false,
            "selection": [
              {
                "v": {
                  "v": "eBook",
                  "l": "eBook"
                }
              }
            ],
            "selectBlank": false,
            "selectError": false
          }
        ],
        "mode": "record-based"
      }
    }
  ]
JSON
then
  log "transformed ${p} (${projects[$p]})"
else
  error "transform ${p} (${projects[$p]}) failed!"
fi
echo

# ------------- 03 Zeitschriften löschen (Breitenbrunn, Dresden) ------------- #

# spec_Z_02
# - M|ART > Facet > Text facet > "Z" und "GH"
# -- show as: records
# --- All > Edit rows > Remove all matching rows

echo "Zeitschriften löschen (Breitenbrunn, Dresden)..."
if curl -fs \
  --data project="${projects[$p]}" \
  --data-urlencode "operations@-" \
  "${endpoint}/command/core/apply-operations$(refine_csrf)" > /dev/null \
  << "JSON"
  [
    {
      "op": "core/row-removal",
      "engineConfig": {
        "facets": [
          {
            "type": "list",
            "name": "M|ART",
            "expression": "value",
            "columnName": "M|ART",
            "invert": false,
            "omitBlank": false,
            "omitError": false,
            "selection": [
              {
                "v": {
                  "v": "GH",
                  "l": "GH"
                }
              },
              {
                "v": {
                  "v": "Z",
                  "l": "Z"
                }
              }
            ],
            "selectBlank": false,
            "selectError": false
          }
        ],
        "mode": "record-based"
      }
    }
  ]
JSON
then
  log "transformed ${p} (${projects[$p]})"
else
  error "transform ${p} (${projects[$p]}) failed!"
fi
echo

# ----------------------- 04 Makulierte Medien löschen ----------------------- #

# spec_Z_03
# - E|EXSTA > Facet > Text facet > "M"
# -- show as: rows
# --- All > Edit rows > Remove all matching rows

echo "Makulierte Medien löschen..."
if curl -fs \
  --data project="${projects[$p]}" \
  --data-urlencode "operations@-" \
  "${endpoint}/command/core/apply-operations$(refine_csrf)" > /dev/null \
  << "JSON"
  [
    {
      "op": "core/row-removal",
      "engineConfig": {
        "facets": [
          {
            "type": "list",
            "name": "E|EXSTA",
            "expression": "value",
            "columnName": "E|EXSTA",
            "invert": false,
            "omitBlank": false,
            "omitError": false,
            "selection": [
              {
                "v": {
                  "v": "M",
                  "l": "M"
                }
              }
            ],
            "selectBlank": false,
            "selectError": false
          }
        ],
        "mode": "row-based"
      }
    }
  ]
JSON
then
  log "transformed ${p} (${projects[$p]})"
else
  error "transform ${p} (${projects[$p]}) failed!"
fi
echo

# ---------------------------------- 05 File --------------------------------- #

echo "Bibliothekskürzel aus Import-Dateiname..."
if curl -fs \
  --data project="${projects[$p]}" \
  --data-urlencode "operations@-" \
  "${endpoint}/command/core/apply-operations$(refine_csrf)" > /dev/null \
  << "JSON"
  [
    {
      "op": "core/text-transform",
      "engineConfig": {
        "facets": [],
        "mode": "row-based"
      },
      "columnName": "File",
      "expression": "grel:with([ ['bautzen.tsv','BZ'], ['breitenbrunn.tsv','BB'], ['dresden.tsv','DD'],  ['glauchau.tsv','GC'], ['plauen.tsv','PL'] ], mapping, forEach(mapping, m, if(value == m[0], m[1], '')).join(''))",
      "onError": "keep-original",
      "repeat": false,
      "repeatCount": 10
    }
  ]
JSON
then
  log "transformed ${p} (${projects[$p]})"
else
  error "transform ${p} (${projects[$p]}) failed!"
fi
echo

# ---------------------------------- 06 0100 --------------------------------- #

# spec_B_T_01
# TODO: Aufteilung in 0100 / 0110 nach Nummernkreisen
# TODO: Korrekturen für <9 und >10-stellige
echo "K10plus-PPNs in 0100..."
if curl -fs \
  --data project="${projects[$p]}" \
  --data-urlencode "operations@-" \
  "${endpoint}/command/core/apply-operations$(refine_csrf)" > /dev/null \
  << "JSON"
  [
    {
      "op": "core/column-addition",
      "engineConfig": {
        "facets": [
          {
            "type": "list",
            "name": "M|IDNR",
            "expression": "grel:value.length()",
            "columnName": "M|IDNR",
            "invert": false,
            "omitBlank": false,
            "omitError": false,
            "selection": [
              {
                "v": {
                  "v": 9,
                  "l": "9"
                }
              },
              {
                "v": {
                  "v": 10,
                  "l": "10"
                }
              }
            ],
            "selectBlank": false,
            "selectError": false
          }
        ],
        "mode": "row-based"
      },
      "baseColumnName": "M|IDNR",
      "expression": "grel:value",
      "onError": "set-to-blank",
      "newColumnName": "0100",
      "columnInsertIndex": 3
    }
  ]
JSON
then
  log "transformed ${p} (${projects[$p]})"
else
  error "transform ${p} (${projects[$p]}) failed!"
fi
echo

# ---------------------------------- 07 2199 --------------------------------- #

# spec_B_T_49
# TODO: Titeldaten ohne Exemplare
echo "Nummern aus Datenkonversion 2199..."
if curl -fs \
  --data project="${projects[$p]}" \
  --data-urlencode "operations@-" \
  "${endpoint}/command/core/apply-operations$(refine_csrf)" > /dev/null \
  << "JSON"
  [
    {
      "op": "core/column-addition",
      "engineConfig": {
        "facets": [],
        "mode": "row-based"
      },
      "baseColumnName": "M|MEDNR",
      "expression": "grel:'BA' + cells['File'].value + value",
      "onError": "set-to-blank",
      "newColumnName": "2199",
      "columnInsertIndex": 3
    }
  ]
JSON
then
  log "transformed ${p} (${projects[$p]})"
else
  error "transform ${p} (${projects[$p]}) failed!"
fi
echo

# --------------------------------- 08 7100B --------------------------------- #

# spec_B_E_15
echo "Bibliothekssigel 7100B..."
if curl -fs \
  --data project="${projects[$p]}" \
  --data-urlencode "operations@-" \
  "${endpoint}/command/core/apply-operations$(refine_csrf)" > /dev/null \
  << "JSON"
  [
    {
      "op": "core/column-addition",
      "engineConfig": {
        "facets": [],
        "mode": "row-based"
      },
      "baseColumnName": "E|ZWGST",
      "expression": "grel:value.replace('BB','Brt 1').replace('BZ','Bn 3').replace('DD','D 161').replace('EH','D 275').replace('GC','Gla 1').replace('PL','Pl 11')",
      "onError": "set-to-blank",
      "newColumnName": "7100B",
      "columnInsertIndex": 3
    }
  ]
JSON
then
  log "transformed ${p} (${projects[$p]})"
else
  error "transform ${p} (${projects[$p]}) failed!"
fi
echo

# --------------------------------- 09 7100f --------------------------------- #

# spec_B_E_13
echo "Zweigstelle 7100f..."
if curl -fs \
  --data project="${projects[$p]}" \
  --data-urlencode "operations@-" \
  "${endpoint}/command/core/apply-operations$(refine_csrf)" > /dev/null \
  << "JSON"
  [
    {
      "op": "core/column-addition",
      "engineConfig": {
        "facets": [],
        "mode": "row-based"
      },
      "baseColumnName": "E|ZWGST",
      "expression": "grel:value",
      "onError": "set-to-blank",
      "newColumnName": "7100f",
      "columnInsertIndex": 3
    }
  ]
JSON
then
  log "transformed ${p} (${projects[$p]})"
else
  error "transform ${p} (${projects[$p]}) failed!"
fi
echo

# --------------------------------- 10 7100a --------------------------------- #

# spec_B_E_07
echo "Standort 7100a..."
if curl -fs \
  --data project="${projects[$p]}" \
  --data-urlencode "operations@-" \
  "${endpoint}/command/core/apply-operations$(refine_csrf)" > /dev/null \
  << "JSON"
  [
    {
      "op": "core/column-addition",
      "engineConfig": {
        "facets": [],
        "mode": "row-based"
      },
      "baseColumnName": "E|STA1",
      "expression": "grel:value.replace('␟',' ')",
      "onError": "set-to-blank",
      "newColumnName": "7100a",
      "columnInsertIndex": 3
    }
  ]
JSON
then
  log "transformed ${p} (${projects[$p]})"
else
  error "transform ${p} (${projects[$p]}) failed!"
fi
echo

# --------------------------------- 11 2000 ---------------------------------- #

# TODO: ISMN in 2020
# spec_B_T_04, spec_B_T_05
echo "ISBN 2000..."
if curl -fs \
  --data project="${projects[$p]}" \
  --data-urlencode "operations@-" \
  "${endpoint}/command/core/apply-operations$(refine_csrf)" > /dev/null \
  << "JSON"
  [
    {
      "op": "core/column-addition",
      "engineConfig": {
        "facets": [],
        "mode": "record-based"
      },
      "baseColumnName": "M|ISBN",
      "expression": "grel:[ forNonBlank(cells['M|ISBN'].value,v,if(isNumeric(v[0]),v,null),null), forNonBlank(cells['M|ISBN2'].value,v,if(isNumeric(v[0]),v,null),null) ].uniques().join('␟')",
      "onError": "set-to-blank",
      "newColumnName": "2000",
      "columnInsertIndex": 10,
      "description": "Create column 2000 at index 10 based on column M|ISBN using expression grel:[ forNonBlank(cells['M|ISBN'].value,v,if(isNumeric(v[0]),v,null),null), forNonBlank(cells['M|ISBN2'].value,v,if(isNumeric(v[0]),v,null),null) ].uniques().join('␟')"
    }
  ]
JSON
then
  log "transformed ${p} (${projects[$p]})"
else
  error "transform ${p} (${projects[$p]}) failed!"
fi
echo

# ================================== EXPORT ================================== #

# Export der PICA3-Spalten als CSV
format="csv"
echo "export ${p} to ${format} file using template..."
IFS= read -r -d '' template << "TEMPLATE"
{{
with(
  [
    '2199',
    '0100',
    '2000',
    '7100B',
    '7100f',
    '7100a'
  ],
  columns,
  if(
    row.index == 0,
    forEach(
        columns,
        cn,
        cn.escape('csv')
      ).join(',')
      + '\n'
      + with(
        forEach(
          columns,
          cn,
          forNonBlank(
            cells[cn].value,
            v,
            v.escape('csv'),
            '␀'
          )
        ).join(',').replace('␀',''),
        r,
        if(
          isNonBlank(r.split(',').join(',')),
          r + '\n',
          ''
        )
      ),
    with(
      forEach(
        columns,
        cn,
        forNonBlank(
          cells[cn].value,
          v,
          v.escape('csv'),
          '␀'
        )
      ).join(',').replace('␀',''),
      r,
      if(
        isNonBlank(r.split(',').join(',')),
        r + '\n',
        ''
      )
    )
  )
)
}}
TEMPLATE
if echo "${template}" | head -c -2 | curl -fs \
  --data project="${projects[$p]}" \
  --data format="template" \
  --data prefix="" \
  --data suffix="" \
  --data separator="" \
  --data engine='{"facets":[],"mode":"row-based"}' \
  --data-urlencode template@- \
  "${endpoint}/command/core/export-rows" \
  > "${workspace}/${p}.${format}"
then
  log "exported ${p} (${projects[$p]}) to ${workspace}/${p}.${format}"
else
  error "export of ${p} (${projects[$p]}) failed!"
fi
echo

# ================================== FINISH ================================== #

refine_stop; echo
