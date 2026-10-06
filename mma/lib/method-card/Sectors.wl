(* Sector masks, resident ordering, and slices of an already checked ordered DE.
   Loaded inside CanonMethodCard`Private` by MethodCardCore.wl. *)

SectorBits[integral_, propagatorSlots_List] := ReplacePart[
  ConstantArray[0, Length[integral]],
  Thread[({#} & /@ propagatorSlots) -> (Boole[# > 0] & /@ (List @@ integral)[[propagatorSlots]])]];

FormatMasterArtifacts[prepared_Association, sourceMasters_List, sourceHash_String] := Module[
  {bits, sectorID, sectors, sectorRank, masters},
  bits[master_] := SectorBits[master, prepared["propagator_slots"]];
  sectorID[mask_] := mask . 2^Range[0, Length[mask] - 1];
  sectors = (<|"id" -> sectorID[bits[First[#]]], "propagator_count" -> Total[bits[First[#]]],
      "sector_bits" -> bits[First[#]], "master_count" -> Length[#]|> &) /@ GatherBy[sourceMasters, bits];
  sectors = SortBy[sectors, {#["propagator_count"], #["id"]} &];
  sectorRank = AssociationThread[Lookup[sectors, "id"] -> Range[Length[sectors]]];
  masters = First /@ SortBy[MapIndexed[{#1, First[#2]} &, sourceMasters],
    {sectorRank[sectorID[bits[First[#]]]], Last[#]} &];
  <|"sector_manifest" -> <|
    "schema" -> "canon-neu/sector-manifest/v1", "family_ref" -> prepared["family_ref"],
    "source_sha256" -> sourceHash, "propagator_slots" -> prepared["propagator_slots"],
    "sector_convention" -> prepared["sector_convention"],
    "bit_order" -> "integral index order; a1 is the least-significant bit; ISP bits are zero",
    "ordering" -> "ascending (propagator_count, id)", "sectors" -> sectors|>,
    "master_basis" -> <|
    "schema" -> "canon-neu/master-basis/v1", "family_ref" -> prepared["family_ref"],
    "basis_ref" -> prepared["basis_ref"],
    "topology" -> Lookup[prepared, "integral_head", prepared["topology"]],
    "source_sha256" -> sourceHash, "index_order" -> prepared["index_order"],
    "ordering" -> "ascending sector-manifest rank (propagator_count, id); original source position within sector",
    "masters" -> masters|>|>
];

SectorDEArtifacts[ordered_Association, manifest_Association, current_Association] := Module[
  {positions, basis, lower, sector, basisID},
  positions = Flatten @ Position[
    (SectorBits[#, manifest["propagator_slots"]] & /@ ordered["basis"]),
    current["sector_bits"], {1}];
  basis = ordered["basis"][[positions]];
  lower = Select[manifest["sectors"],
    #["sector_bits"] =!= current["sector_bits"] &&
      And @@ MapThread[LessEqual, {#["sector_bits"], current["sector_bits"]}] &];
  sector = KeyTake[current, {"id", "propagator_count"}];
  basisID = ordered["basis_id"] <> "/sector-" <> ToString[sector["id"]];
  <|"sector_basis" -> <|
      "schema" -> "canon-neu/sector-basis/v1", "sector" -> sector,
      "family_id" -> ordered["family_id"], "basis_id" -> basisID, "basis" -> basis|>,
    "sector_cut_de" -> <|
      "schema" -> "canon-neu/sector-cut-de/v1", "sector" -> sector,
      "family_id" -> ordered["family_id"], "basis_id" -> basisID,
      "coefficient_domain" -> ordered["coefficient_domain"], "basis" -> basis,
      "variables" -> ordered["variables"], "regulator" -> ordered["regulator"],
      "matrices" -> (#[[positions, positions]] & /@ ordered["matrices"]),
      "sector_boundaries" -> {{1, Length[basis]}},
      "proper_subsectors" -> (KeyTake[#, {"id", "propagator_count"}] & /@ lower)|>,
    "resident_positions" -> positions|>
];
