Require Import Ascii Bool String List.
Require Import Lib.CommonTactics Lib.ilist Lib.Word Lib.Struct Lib.Indexer.
Require Import Kami.Syntax Kami.ParametricSyntax Kami.Semantics Kami.Notations Kami.SemFacts.
Require Import Kami.Wf Kami.Tactics Kami.Specialize Kami.Duplicate Kami.RefinementFacts.
Require Import Ex.Msi Ex.MemTypes Ex.RegFile Ex.L1Cache Ex.ChildParent Ex.MemDir.
Require Import Ex.Fifo Ex.NativeFifo Ex.FifoCorrect Kami.ParametricEquiv Kami.ParametricInline Ex.Names.

Set Implicit Arguments.

Section MemCache.
  Variables IdxBits TagBits LgNumDatas DataBytes: nat.
  Variable Id: Kind.

  Variable FifoSize: nat.
  Variable LgNumChildren: nat.

  Definition l1Cache1 := getMetaModulesFromSinNat LgNumChildren (l1Cache IdxBits TagBits LgNumDatas DataBytes Id).


  Definition l1cs1 :=
      (@getMetaModulesFromRegFile
         LgNumChildren
         {| nameVal := cs--dataArray; goodName :=  rfgn cs eq_refl dataArray eq_refl |}
         ({| nameVal := cs--read0; goodName :=  rfgn cs eq_refl read eq_refl|}
            ::
            {| nameVal := cs--read1; goodName :=  rfgn cs eq_refl read eq_refl|}
            ::
            {| nameVal := cs--read2; goodName :=  rfgn cs eq_refl read eq_refl|}
            ::
            {| nameVal := cs--read3; goodName :=  rfgn cs eq_refl read eq_refl|}
            ::
            {| nameVal := cs--read4; goodName :=  rfgn cs eq_refl read eq_refl|}
            ::
            {| nameVal := cs--read5; goodName :=  rfgn cs eq_refl read eq_refl|}
            ::
            {| nameVal := cs--read6; goodName :=  rfgn cs eq_refl read eq_refl|}
            ::
            {| nameVal := cs--read7; goodName :=  rfgn cs eq_refl read eq_refl|}
            ::
            {| nameVal := cs--read8; goodName :=  rfgn cs eq_refl read eq_refl|}
            :: nil)
         {| nameVal := cs--write; goodName :=  rfgn cs eq_refl write eq_refl|} IdxBits Msi Default).
  Definition l1tag1 :=
      (@getMetaModulesFromRegFile
         LgNumChildren
         {| nameVal := tag--dataArray; goodName :=  rfgn tag eq_refl dataArray eq_refl |}
         ({| nameVal := tag--read0; goodName :=  rfgn tag eq_refl read0 eq_refl |}
            ::
            {| nameVal := tag--read1; goodName :=  rfgn tag eq_refl read1 eq_refl |}
            ::
            {| nameVal := tag--read2; goodName :=  rfgn tag eq_refl read2 eq_refl |}
            ::
            {| nameVal := tag--read3; goodName :=  rfgn tag eq_refl read3 eq_refl |}
            ::
            {| nameVal := tag--read4; goodName :=  rfgn tag eq_refl read4 eq_refl |}
            ::
            {| nameVal := tag--read5; goodName :=  rfgn tag eq_refl read5 eq_refl |}
            ::
            {| nameVal := tag--read6; goodName :=  rfgn tag eq_refl read6 eq_refl |}
            ::
            {| nameVal := tag--read7; goodName :=  rfgn tag eq_refl read7 eq_refl |}
            ::
            {| nameVal := tag--read8; goodName :=  rfgn tag eq_refl read8 eq_refl |}
            ::
            nil)
         {| nameVal := tag--write; goodName :=  rfgn tag eq_refl write eq_refl |} IdxBits (L1Cache.Tag TagBits) Default).
  Definition l1line1 :=
      (@getMetaModulesFromRegFile
         LgNumChildren
         {| nameVal := line--dataArray; goodName :=  rfgn line eq_refl dataArray eq_refl |}
         ({| nameVal := line--read; goodName :=  rfgn line eq_refl read eq_refl |} :: nil)
         {| nameVal := line--write; goodName :=  rfgn line eq_refl write eq_refl |} IdxBits
         (L1Cache.Line LgNumDatas DataBytes) Default).

  (*
  Definition l1cs1 := @getMetaModulesFromRegFile LgNumChildren {| nameVal := Indexer.withPrefix cs dataArray;
                                                                 goodName :=  rfgn cs eq_refl dataArray eq_refl |}
                                               {| nameVal := Indexer.withPrefix cs read; goodName :=  rfgn cs eq_refl read eq_refl|}
                                               {| nameVal := Indexer.withPrefix cs write; goodName :=  rfgn cs eq_refl write eq_refl|} IdxBits Msi Default.
  Definition l1tag1 :=
    @getMetaModulesFromRegFile LgNumChildren
                              {| nameVal := Indexer.withPrefix tag dataArray; goodName :=  rfgn tag eq_refl dataArray eq_refl |}
                              {| nameVal := Indexer.withPrefix tag read; goodName :=  rfgn tag eq_refl read eq_refl |}
                              {| nameVal := Indexer.withPrefix tag write; goodName :=  rfgn tag eq_refl write eq_refl |} IdxBits (L1Cache.Tag TagBits) Default.
  Definition l1line1 :=
    @getMetaModulesFromRegFile LgNumChildren
                              {| nameVal := Indexer.withPrefix line dataArray; goodName :=  rfgn line eq_refl dataArray eq_refl |}
                              {| nameVal := Indexer.withPrefix line read; goodName :=  rfgn line eq_refl read eq_refl |}
                              {| nameVal := Indexer.withPrefix line write; goodName :=  rfgn line eq_refl write eq_refl |} IdxBits (L1Cache.Line LgNumDatas DataBytes) Default.
   *)

  Definition l11 := l1Cache1 ++++ (l1cs1 ++++ l1tag1 ++++ l1line1).

  Definition MIdxBits := IdxBits + TagBits.

  Definition fifoRqToP1 :=
    getMetaModulesFromSinNat
      LgNumChildren (simpleFifoS rqToParent (rsz FifoSize) (Struct (RqToP MIdxBits Id))
                                 eq_refl).
  
  Definition fifoRsToP1 :=
    getMetaModulesFromSinNat
      LgNumChildren (simpleFifoS rsToParent (rsz FifoSize)
                                 (Struct (RsToP MIdxBits LgNumDatas DataBytes)) eq_refl).
  Definition fifoFromP1 :=
    getMetaModulesFromSinNat
      LgNumChildren (simpleFifoS fromParent (rsz FifoSize)
                                 (Struct (FromP MIdxBits LgNumDatas DataBytes Id))
                                 eq_refl).

  Definition l1C1 :=
    l11 ++++ (fifoRqToP1 ++++ fifoRsToP1 ++++ fifoFromP1).

  Definition childParent1 := childParent MIdxBits LgNumDatas DataBytes LgNumChildren Id.

  Definition fifoRqFromC1 :=
    fifoM rqFromChild (rsz FifoSize) (Struct (RqFromC MIdxBits LgNumChildren Id)) eq_refl.
  Definition fifoRsFromC1 :=
    simpleFifoM rsFromChild (rsz FifoSize)
                (Struct (RsFromC MIdxBits LgNumDatas DataBytes LgNumChildren)) eq_refl.
  Definition fifoToC1 := simpleFifoM toChild (rsz FifoSize)
                                    (Struct (ToC MIdxBits LgNumDatas
                                                 DataBytes LgNumChildren Id)) eq_refl.

  Definition childParentC1 := ((MetaMod childParent1) ++++ ((MetaMod fifoRqFromC1) ++++ (MetaMod fifoRsFromC1) ++++ (MetaMod fifoToC1)))%kami.

  Definition memDir1 := memDir MIdxBits LgNumDatas DataBytes LgNumChildren Id.

  Definition mline1 :=
      (@MetaRegFile
         {| nameVal := mline--dataArray; goodName := rfgn mline eq_refl dataArray eq_refl |}
         ({| nameVal := mline--read; goodName := rfgn mline eq_refl read eq_refl|} :: nil)
         {| nameVal := mline--write; goodName := rfgn mline eq_refl write eq_refl |}
         MIdxBits (MemDir.Line LgNumDatas DataBytes) Default).

  Definition mdir1 :=
      (@MetaRegFile
         {| nameVal := mcs--dataArray; goodName := rfgn mcs eq_refl dataArray eq_refl |}
         ({| nameVal := mcs--read0; goodName := rfgn mcs eq_refl read0 eq_refl |}
            ::
            {| nameVal := mcs--read1; goodName := rfgn mcs eq_refl read1 eq_refl |}
            ::
            {| nameVal := mcs--read2; goodName := rfgn mcs eq_refl read2 eq_refl |}
            ::
            {| nameVal := mcs--read3; goodName := rfgn mcs eq_refl read3 eq_refl |}
            ::          
            nil)
         {| nameVal := mcs--write; goodName := rfgn mcs eq_refl write eq_refl |}
         MIdxBits (MemDir.Dir LgNumChildren) Default).


  (*
  Definition mline1 := @MetaRegFile
                              {| nameVal := Indexer.withPrefix mline dataArray; goodName := rfgn mline eq_refl dataArray eq_refl |}
                              {| nameVal := Indexer.withPrefix mline read; goodName := rfgn mline eq_refl read eq_refl|}
                              {| nameVal := Indexer.withPrefix mline write; goodName := rfgn mline eq_refl write eq_refl |} MIdxBits (MemDir.Line LgNumDatas DataBytes) Default.

  Definition mdir1 := @MetaRegFile
                              {| nameVal := Indexer.withPrefix mcs dataArray; goodName := rfgn mcs eq_refl dataArray eq_refl |}
                              {| nameVal := Indexer.withPrefix mcs read; goodName := rfgn mcs eq_refl read eq_refl |}
                              {| nameVal := Indexer.withPrefix mcs write; goodName := rfgn mcs eq_refl write eq_refl |} MIdxBits (MemDir.Dir LgNumChildren) Default.
   *)

  Definition memDirC1 := ((MetaMod memDir1) ++++ mline1 ++++ mdir1)%kami.

  Definition memCache1 := (l1C1 ++++ childParentC1 ++++ memDirC1)%kami.

  Require Import Ex.MemCache Kami.Tactics.
  
  Lemma memCache_flatten:
    flattenMeta memCache1 = memCache IdxBits TagBits LgNumDatas DataBytes Id FifoSize LgNumChildren.
  Proof.
    reflexivity.
  Qed.

  Lemma memCache_refines:
    MetaMod (memCache IdxBits TagBits LgNumDatas DataBytes Id FifoSize LgNumChildren) <|=|> memCache1.
  Proof.
    rewrite <- memCache_flatten.
    apply flattenMetaEquiv.
    knodup_regs.
  Qed.
End MemCache.

