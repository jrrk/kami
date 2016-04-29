Require Import String Streams.
Require Import Lib.Indexer.
Require Import Lts.Syntax Lts.Semantics.

Set Implicit Arguments.

Section StreamMod.
  Variable modName: string.
  Variable A : Kind.
  Variable default : ConstT A.
  Variable stream : Stream (ConstT A).

  Definition nk := NativeKind (const default).

  Notation "^ s" := (modName .. s) (at level 0).

  Definition streamMod := MODULE {
    RegisterN ^"stream" : nk <- (NativeConst _ stream)

    with Method ^"get"() : A :=
    (ReadReg (^"stream") nk (fun s => 
    WriteReg (^"stream") (Var _ nk (tl s))
     (Ret $$(hd s))))%kami
  }.

  (* Section Spec. *)
  (*   Lemma regsInDomain_streamMod: RegsInDomain streamMod. *)
  (*   Proof. *)
  (*     regsInDomain_tac. *)
  (*   Qed. *)
  (* End Spec. *)

End StreamMod.

Section Fifo.
  Variable A: Kind.
  Definition f := MODULE {
                      RegisterN "x": NativeKind (type A) <- (NativeConst _ (ConstT A))
                      with Method "enq"(d: A): Void :=
                        Write "x" <- #d;
                        Retv
                    }.
End Fifo.