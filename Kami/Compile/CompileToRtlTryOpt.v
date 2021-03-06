Require Import Kami.Syntax String Compile.Rtl Lib.ilist Lib.Struct
        Lib.StringEq List Compare_dec Compile.Helpers Coq.Strings.Ascii PeanoNat Lib.Word.

Require Import Coq.FSets.FSetAVL Coq.Structures.OrderedType Lib.StringAsOT Lib.StringStringAsOT.
Module M := FSetAVL.Make(String_as_OT).
Module MM := FSetAVL.Make(StringString_as_OT).

Set Implicit Arguments.
Set Asymmetric Patterns.

Open Scope string.

Local Notation nil_nat := (nil: list nat).
Definition getRegActionRead a s := (a ++ "#" ++ s ++ "#_read", nil_nat).
Definition getRegActionWrite a s := (a ++ "#" ++ s ++ "#_write", nil_nat).
Definition getRegActionEn a s := (a ++ "#" ++ s ++ "#_en", nil_nat).

Definition getMethCallActionArg a f := (a ++ "#" ++ f ++ "#_arg", nil_nat).
Definition getMethCallActionEn a f := (a ++ "#" ++ f ++ "#_en", nil_nat).

Definition getMethRet f := (f ++ "#_ret", nil_nat).
Definition getMethArg f := (f ++ "#_arg", nil_nat).

Definition getActionGuard r := (r ++ "#_g", nil_nat).
Definition getActionEn r := (r ++ "#_en", nil_nat).

Definition getRegIndexWrite r (i: nat) := (r ++ "#_write", i :: nil).
Definition getRegIndexWriteEn r (i: nat) := (r ++ "#_writeEn", i :: nil).
Definition getRegIndexRead r (i: nat) := (r ++ "#_read", i :: nil).

Close Scope string.

Local Definition inc ns := match ns with
                             | nil => nil
                             | x :: xs => S x :: xs
                           end.

Local Notation cast k' v := match k' with
                              | SyntaxKind k => v
                              | NativeKind _ c => c
                            end.

Section Compile.
  Variable name: string.
  Axiom cheat: forall t, t.
  Fixpoint convertExprToRtl k (e: Expr (fun _ => list nat) (SyntaxKind k)): RtlExpr k :=
    match e in Expr _ (SyntaxKind k) return RtlExpr k with
      | Var k' x' =>   match k' return
                             (forall x,
                                match k' return (Expr (fun _ => list nat) k' -> Set) with
                                  | SyntaxKind k => fun _ => RtlExpr k
                                  | NativeKind _ _ => fun _ => IDProp
                                end (Var (fun _ : Kind => list nat) k' x))
                       with
                         | SyntaxKind k => fun x => RtlReadWire k (name, x)
                         | NativeKind t c => fun _ => idProp
                       end x'
      | Const k x => RtlConst x
      | UniBool x x0 => RtlUniBool x (@convertExprToRtl _ x0)
      | BinBool x x0 x1 => RtlBinBool x (@convertExprToRtl _ x0) (@convertExprToRtl _ x1)
      | UniBit n1 n2 x x0 => RtlUniBit x (@convertExprToRtl _ x0)
      | BinBit n1 n2 n3 x x0 x1 => RtlBinBit x (@convertExprToRtl _ x0) (@convertExprToRtl _ x1)
      | BinBitBool n1 n2 x x0 x1 => RtlBinBitBool x (@convertExprToRtl _ x0) (@convertExprToRtl _ x1)
      | Eq k x x0 => RtlEq (@convertExprToRtl _ x) (@convertExprToRtl _ x0)
      | ReadIndex i k x x0 => RtlReadIndex (@convertExprToRtl _ x) (@convertExprToRtl _ x0)
      | ReadField n ls i x => RtlReadField i (@convertExprToRtl _ x)
      | BuildVector k n x => RtlBuildVector (mapVec (@convertExprToRtl k) x)
      | BuildStruct n attrs x =>
        RtlBuildStruct
          ((fix buildStruct n attrs x :=
              match x in ilist _ attrs return ilist (fun a => RtlExpr (attrType a)) attrs with
                | inil => inil (fun a => RtlExpr (attrType a))
                | icons a na vs h t => icons a (@convertExprToRtl (attrType a) h) (buildStruct na vs t)
              end) n attrs x)
      | UpdateVector i k x x0 x1 => RtlUpdateVector (@convertExprToRtl _ x) (@convertExprToRtl _ x0) (@convertExprToRtl _ x1)
      | ITE k' x x0' x1' =>
        match k' return
              (forall x0 x1,
                 match k' return (Expr (fun _ => list nat) k' -> Set) with
                   | SyntaxKind k => fun _ => RtlExpr k
                   | NativeKind _ _ => fun _ => IDProp
                 end (ITE x x0 x1))
        with
          | SyntaxKind k => fun x0 x1 => RtlITE (@convertExprToRtl _ x) (@convertExprToRtl _ x0) (@convertExprToRtl _ x1)
          | NativeKind t c => fun _ _ => idProp
        end x0' x1'
      | ReadArrayIndex i k idx arr =>
        RtlReadArrayIndex (@convertExprToRtl _ idx) (@convertExprToRtl _ arr)
      | BuildArray k n x => RtlBuildArray (Vector.map (@convertExprToRtl _) x)
      | UpdateArray i k x x0 x1 =>
        RtlUpdateArray (@convertExprToRtl _ x) (@convertExprToRtl _ x0) (@convertExprToRtl _ x1)
    end.

  Fixpoint convertActionToRtl_noGuard k (a: ActionT (fun _ => list nat) k) enable startList retList :=
    match a in ActionT _ _ with
      | MCall meth k argExpr cont =>
        (getMethCallActionArg name meth, existT _ (arg k) (convertExprToRtl argExpr)) ::
        (getMethCallActionEn name meth, existT _ Bool enable) ::
        (name, startList, existT _ (ret k) (RtlReadWire (ret k) (getMethRet meth))) ::
        convertActionToRtl_noGuard (cont startList) enable (inc startList) retList
      | Let_ k' expr cont =>
        let wires := convertActionToRtl_noGuard (cont (cast k' startList)) enable (inc startList) retList in
        match k' return Expr (fun _ => list nat) k' -> list (string * list nat * sigT RtlExpr) with
          | SyntaxKind k => fun expr => (name, startList, existT _ k (convertExprToRtl expr)) :: wires
          | _ => fun _ => wires
        end expr
      | ReadNondet k' cont =>
        (* should be same as the case of NativeKind Let_ *)
        convertActionToRtl_noGuard (cont (cast k' startList)) enable (inc startList) retList
      | ReadReg r k' cont =>
        let wires := convertActionToRtl_noGuard (cont (cast k' startList)) enable (inc startList) retList in
        match k' return list (string * list nat * sigT RtlExpr) with
          | SyntaxKind k => (name, startList,
                             existT _ k (RtlReadWire k (getRegActionRead name r))) :: wires
          | _ => wires
        end
      | WriteReg r k' expr cont =>
        let wires := convertActionToRtl_noGuard cont enable startList retList in
        match k' return Expr (fun _ => list nat) k' -> list (string * list nat * sigT RtlExpr) with
          | SyntaxKind k => fun expr => (getRegActionWrite name r, existT _ k (convertExprToRtl expr)) ::
                                        (getRegActionEn name r, existT _ Bool enable) :: wires
          | _ => fun _ => wires
        end expr
      | Assert_ pred cont => convertActionToRtl_noGuard cont enable startList retList
      | Return x => (name, retList, existT _ k (convertExprToRtl x)) :: nil
      | IfElse pred ktf t f cont =>
        convertActionToRtl_noGuard t (RtlBinBool And enable (convertExprToRtl pred)) (0 :: startList) (startList) ++
        convertActionToRtl_noGuard t
          (RtlBinBool And enable (RtlUniBool Neg (convertExprToRtl pred))) (0 :: inc startList) (inc startList) ++
        (name, inc (inc startList),
         existT _ ktf (RtlITE (convertExprToRtl pred) (RtlReadWire ktf (name, startList)) (RtlReadWire ktf (name, inc startList)))) ::
        convertActionToRtl_noGuard (cont (inc (inc startList))) enable (inc (inc (inc startList))) retList
    end.

  Fixpoint convertActionToRtl_guard k (a: ActionT (fun _ => list nat) k) startList: RtlExpr Bool :=
    match a in ActionT _ _ with
      | MCall meth k argExpr cont =>
        RtlBinBool And (RtlReadWire Bool (getActionGuard meth)) (convertActionToRtl_guard (cont startList) (inc startList))
      | Let_ k' expr cont =>
        convertActionToRtl_guard (cont (cast k' startList)) (inc startList)
      | ReadNondet k' cont =>
        convertActionToRtl_guard (cont (cast k' startList)) (inc startList)
      | ReadReg r k' cont =>
        convertActionToRtl_guard (cont (cast k' startList)) (inc startList)
      | WriteReg r k' expr cont =>
        convertActionToRtl_guard cont startList
      | Assert_ pred cont => RtlBinBool And (convertExprToRtl pred)
                                        (convertActionToRtl_guard cont startList)
      | Return x => RtlConst (ConstBool true)
      | IfElse pred ktf t f cont =>
        RtlBinBool And
                   (RtlITE (convertExprToRtl pred) (convertActionToRtl_guard t (0 :: startList))
                           (convertActionToRtl_guard t (0 :: inc startList)))
                   (convertActionToRtl_guard (cont (inc (inc startList))) (inc (inc (inc startList))))
    end.
End Compile.


(* Set the enables correctly in the following two functions *)

Definition computeRuleAssigns (r: Attribute (Action Void)) :=
  (getActionGuard (attrName r),
   existT _ Bool (convertActionToRtl_guard (attrName r) (attrType r (fun _ => list nat)) (1 :: nil))) ::
  convertActionToRtl_noGuard (attrName r) (attrType r (fun _ => list nat)) (RtlConst (ConstBool true)) (1 :: nil) (0 :: nil).

Definition computeMethAssigns (f: DefMethT) :=
  (getActionGuard (attrName f),
   existT _ Bool (convertActionToRtl_guard (attrName f) (projT2 (attrType f) (fun _ => list nat) (1 :: nil)) (2 :: nil))) ::
  (attrName f, 1 :: nil,
   existT _ (arg (projT1 (attrType f))) (RtlReadWire (arg (projT1 (attrType f))) (getMethArg (attrName f)))) ::
  convertActionToRtl_noGuard (attrName f) (projT2 (attrType f) (fun _ => list nat) (1 :: nil))
   ((* RtlReadWire Bool (getActionEn (attrName f)) *) RtlConst (ConstBool true)) (2 :: nil) (0 :: nil).

Definition computeMethRets (f: DefMethT) :=
  (getMethRet (attrName f), existT _ _ (RtlReadWire (ret (projT1 (attrType f))) (attrName f, 0 :: nil))).

Fixpoint getWritesAction k (a: ActionT typeUT k) :=
  match a with
    | MCall meth k argExpr cont => getWritesAction (cont tt)
    | Let_ k' expr cont => getWritesAction (cont (cast k' tt))
    | ReadNondet k' cont => getWritesAction (cont (cast k' tt))
    | ReadReg r k' cont => getWritesAction (cont (cast k' tt))
    | WriteReg r k expr cont => M.add r (getWritesAction cont)
    | IfElse _ _ t f cont => M.union (M.union (getWritesAction t) (getWritesAction f)) (getWritesAction (cont tt))
    | Assert_ x cont => getWritesAction cont
    | Return x => M.empty
  end.

Fixpoint getReadsAction k (a: ActionT typeUT k) :=
  match a with
    | MCall meth k argExpr cont => getReadsAction (cont tt)
    | Let_ k' expr cont => getReadsAction (cont (cast k' tt))
    | ReadNondet k' cont => getReadsAction (cont (cast k' tt))
    | ReadReg r k' cont => M.add r (getReadsAction (cont (cast k' tt)))
    | WriteReg r k expr cont => getReadsAction cont
    | IfElse _ _ t f cont => M.union (M.union (getReadsAction t) (getReadsAction f)) (getReadsAction (cont tt))
    | Assert_ x cont => getReadsAction cont
    | Return x => M.empty
  end.

Definition getReadsRuleBody (r: Attribute (Action Void)) :=
  (getReadsAction (attrType r typeUT)).

Definition getReadsMethBody (f: DefMethT) :=
  (getReadsAction (projT2 (attrType f) typeUT tt)).

Definition getWritesRuleBody (r: Attribute (Action Void)) :=
  (getWritesAction (attrType r typeUT)).

Definition getWritesMethBody (f: DefMethT) :=
  (getWritesAction (projT2 (attrType f) typeUT tt)).

Section UsefulFunctions.
  Variable m: Modules.

  Variable totalOrder: list string.
  Variable ignoreLess: list (string * string).

  Local Notation getFromName getObjects getRegs r :=
    match find (fun a => string_eq r (attrName a)) (getObjects m) with
      | None => M.empty
      | Some rule => getRegs rule
    end.

  Definition getReadsRule r := (getFromName getRules getReadsRuleBody r).
  Definition getWritesRule r := (getFromName getRules getWritesRuleBody r).
  Definition getReadsMeth f := (getFromName getDefsBodies getReadsMethBody f).
  Definition getWritesMeth f := (getFromName getDefsBodies getWritesMethBody f).

  Definition getReads x := M.union (getReadsRule x) (getReadsMeth x).
  Definition getWrites x := M.union (getWritesRule x) (getWritesMeth x).
  
  Definition getCallGraph :=
    fold_left (fun g (r: Attribute (Action Void)) => (attrName r, getCallsRule r) :: g) (getRules m) nil
              ++
              fold_left (fun g (f: DefMethT) => (attrName f, getCallsDm f) :: g) (getDefsBodies m) nil.

  Definition getCallers f := map fst (filter (fun x => if find (string_eq f) (snd x) then true else false) getCallGraph).

  Definition getAllCalls a := getConnectedChain string_dec (getCallGraph) a.

  Definition getExternalCalls :=
    filter (fun f => if find (string_eq (fst f)) (getDefs m) then false else true)
           (getCalls_Sig m).
  
  Definition getAllReads a :=
    fold_left (fun regs f => M.union regs (getReads f)) (getAllCalls a) (getReads a).

  Definition getAllWrites a :=
    fold_left (fun regs f => M.union regs (getWrites f)) (getAllCalls a) (getWrites a).

  Definition correctIgnoreLess :=
    fold_left (fun rest x => match intersect string_dec (getAllCalls (fst x))
                                             (getAllCalls (snd x)) with
                               | nil => MM.add x rest
                               | _ => rest
                             end) ignoreLess MM.empty.

  Definition getWritesWhichCall reg calls := find (fun call => M.mem reg (getWritesMeth call)) calls.

  Definition getWhoWrote rule reg := if M.mem reg (getWritesRule rule)
                                     then Some rule
                                     else getWritesWhichCall reg (getAllCalls rule).

  Section GenerateRegIndicies.
    Variable reg: string.

    Section FindWritePrevPos.
      Variable pos: nat.
      Variable currRule: string.

      Local Fixpoint find_write_prev_pos' currPos (ls: list string) :=
        if lt_dec currPos pos
        then match ls with
               | nil => None
               | x :: xs =>
                 if M.mem reg (getAllWrites x)
                 then
                   if MM.mem (currRule, x) correctIgnoreLess
                   then Some currPos
                   else find_write_prev_pos' (S currPos) xs
                 else find_write_prev_pos' (S currPos) xs
             end
        else None.

      Local Lemma find_write_prev_pos'_correct:
        forall ls currPos i, Some i = find_write_prev_pos' currPos ls  -> (i < pos)%nat.
      Proof.
        induction ls; simpl; intros.
        - destruct (lt_dec currPos pos); discriminate.
        - destruct (lt_dec currPos pos); [ | discriminate].
          destruct (M.mem reg (getAllWrites a)).
          + destruct (MM.mem (currRule, a) correctIgnoreLess); inversion H; subst; auto; eapply IHls; eauto.
          + eapply IHls; eauto.
      Qed.

      Local Definition find_write_prev_pos := find_write_prev_pos' 0 totalOrder.
      
      Local Lemma find_write_prev_pos_correct:
        forall i, Some i = find_write_prev_pos -> (i < pos)%nat.
      Proof.
        eapply find_write_prev_pos'_correct.
      Qed.
    End FindWritePrevPos.

    Fixpoint regIndex' ruleList currPos currTable: list nat :=
      match ruleList with
        | nil => nil
        | x :: xs =>
          match currTable with
            | nil => 0 :: nil
            | y :: ys =>
              (if M.mem reg (M.union (getAllReads x) (getAllWrites x))
               then match find_write_prev_pos currPos x with
                      | Some prev =>
                        max y (nth (currPos - 1 - prev) currTable 0)
                      | None => y
                    end
               else y) :: y :: ys
          end
      end.

    Definition regIndex currPos := nth (length totalOrder - 1 - currPos) (regIndex' totalOrder 0 nil) 0.

    Definition maxRegIndex := hd 0 (regIndex' totalOrder 0 nil).
  End GenerateRegIndicies.

  Definition shareRegDisable posFirst posSecond :=
    fold_left (fun disable reg => if Nat.eq_dec (regIndex reg posFirst) (regIndex reg posSecond)
                                  then true
                                  else disable)
              (M.elements (M.inter (nth posFirst (map getAllWrites totalOrder) M.empty)
                                   (nth posSecond (map (fun x => M.union (getAllReads x) (getAllWrites x)) totalOrder) M.empty)
                          )) false.

  Definition shareMethDisable posFirst posSecond :=
    not_nil (intersect string_dec (nth posFirst (map getAllCalls totalOrder) nil)
                       (nth posSecond (map getAllCalls totalOrder) nil)).

  Definition shareDisable posFirst posSecond := orb (shareRegDisable posFirst posSecond) (shareMethDisable posFirst posSecond).


  Local Fixpoint disables' posFirst posSecond :=
    if lt_dec posFirst posSecond
    then
      match posFirst with
        | 0 => if shareDisable posFirst posSecond
               then match nth_error totalOrder posFirst with
                      | None => nil
                      | Some r => r :: nil
                    end
               else nil
        | S m => if shareDisable posFirst posSecond
                 then match nth_error totalOrder posFirst with
                        | None => disables' m posSecond
                        | Some r => r :: disables' m posSecond
                      end
                 else disables' m posSecond
      end
    else nil.

  Definition getRegType reg :=
    match attrType reg with
      | RegInitCustom (existT (SyntaxKind k) _) => k
      | RegInitDefault (SyntaxKind k) => k
      | _ => Void
    end.

  Definition getRegInitValue reg: ConstT (getRegType reg) :=
      match attrType reg as regT return ConstT match regT with
                                                 | RegInitCustom (existT (SyntaxKind k) _) => k
                                                 | RegInitDefault (SyntaxKind k) => k
                                                 | _ => Void
                                               end with
      | RegInitCustom (existT k v) =>
        match k return ConstFullT k -> ConstT match k with
                                                | SyntaxKind k' => k'
                                                | NativeKind _ _ => Void
                                              end with
          | SyntaxKind _ => fun v => match v with
                                       | SyntaxConst _ v' => v'
                                     end
          | _ => fun _ => WO
        end v
      | RegInitDefault (SyntaxKind k) => getDefaultConst k
      | _ => WO
      end.

  Section OneRule.
    Variable rule: string.

    Definition disables: list string :=
      match find_pos string_dec rule totalOrder with
        | None => nil
        | Some posSecond => disables' (pred posSecond) posSecond
      end.

    Definition computeRuleEn :=
      (getActionEn rule,
       existT RtlExpr Bool
              (fold_left (fun (e: RtlExpr Bool) r => RtlBinBool And e (RtlUniBool Neg (RtlReadWire Bool (getActionEn r))))
                         disables (RtlReadWire Bool (getActionGuard rule)))).

    Definition getRulePos := find_pos string_dec rule totalOrder.

    Definition getRuleRegIndex reg :=
      match getRulePos with
        | None => 0
        | Some x => regIndex reg x
      end.
  End OneRule.

  Local Fixpoint methPos' f ls n :=
    match ls with
      | nil => nil
      | x :: xs => if find (string_eq f) (getAllCalls x)
                   then n :: methPos' f xs (S n)
                   else methPos' f xs (S n)
    end.

  Definition methPos f := methPos' f totalOrder 0.

  Definition noMethContradiction f :=
    fold_left (fun prev r =>
                 andb prev (sameList Nat.eq_dec (map (regIndex r) (methPos f))))
              (M.elements (M.union (getAllReads f) (getAllWrites f))) true.

  Definition getPos a := match getRulePos a, head (methPos a) with
                           | Some x, _ => Some x
                           | _, Some y => Some y
                           | None, None => None
                         end.
  
  Definition computeActionReadIndices a :=
    fold_left (fun rest reg => match getPos a with
                                 | None => rest
                                 | Some idx =>
                                   if M.mem (attrName reg) (getReads a)
                                   then
                                     (getRegActionRead a (attrName reg),
                                      existT RtlExpr (getRegType reg)
                                             (RtlReadWire (getRegType reg)
                                                          (getRegIndexRead (attrName reg) (regIndex (attrName reg) idx))))
                                       ::
                                       rest
                                   else rest
                               end) (getRegInits m) nil.

  
  Section OneReg.
    Variable ty: Kind.
    Variable reg: string.
    
    Local Definition getRegIndexWriters idx :=
      fold_left (fun rest x => match getRulePos x with
                                 | None => rest
                                 | Some p => if Nat.eq_dec (regIndex reg p) idx
                                             then match getWhoWrote x reg with
                                                    | None => rest
                                                    | Some y => y :: rest
                                                  end
                                             else rest
                               end) (map (@attrName _) (getRules m)) nil.
    
    Local Definition getComputeRegIndexWrite' idx :=
      (getRegIndexWrite reg idx,
       existT RtlExpr ty
              (fold_left (fun expr r => RtlITE (RtlReadWire Bool (getActionEn r))
                                               (RtlReadWire ty (getRegActionWrite r reg)) expr) (getRegIndexWriters idx)
                         (RtlReadWire ty (getRegIndexRead reg idx)))).

    Local Fixpoint computeRegIndexWrite' n :=
      match n with
        | 0 => getComputeRegIndexWrite' n :: nil
        | S m => getComputeRegIndexWrite' n :: computeRegIndexWrite' m
      end.

    Definition computeRegIndexWrite := computeRegIndexWrite' (maxRegIndex reg).
    
    Definition computeRegFinalWrite := RtlReadWire ty (getRegIndexWrite reg (maxRegIndex reg)).

    Local Fixpoint connectRegWritesToReads' n :=
      match n with
        | 0 => (getRegIndexRead reg 0, existT RtlExpr ty (RtlReadReg ty reg))
        | S m => (getRegIndexRead reg (S m), existT RtlExpr ty (RtlReadWire ty (getRegIndexWrite reg m)))
      end.

    Definition connectRegWritesToReads := connectRegWritesToReads' (maxRegIndex reg).  
  End OneReg.

  Section Meth.
    Variable meth: string.
    Variable argT: Kind.

    Fixpoint computeMethArg' argT ls :=
      match ls with
        | nil => RtlConst (getDefaultConst argT)
        | x :: nil => RtlReadWire argT (getMethCallActionArg x meth)
        | x :: xs => RtlITE (RtlReadWire Bool (getActionEn x))
                            (RtlReadWire argT (getMethCallActionArg x meth)) (computeMethArg' argT xs)
      end.

    Definition computeMethArg :=
      (getMethArg meth,
       existT RtlExpr argT (computeMethArg' argT (getCallers meth))).
    (*
    Definition computeMethArg :=
      (getMethArg meth,
       existT RtlExpr argT
              (fold_left (fun expr r => RtlITE (RtlReadWire Bool (getActionEn r))
                                               (RtlReadWire argT (getMethCallActionArg r meth)) expr) (getCallers meth)
                         (RtlConst (getDefaultConst argT)))).
     *)
    
    Definition computeMethEn :=
      (getActionEn meth,
       existT RtlExpr Bool
              (fold_left (fun expr r => RtlBinBool Or
                                                   (RtlBinBool And (RtlReadWire Bool (getActionEn r))
                                                               (RtlReadWire Bool (getMethCallActionEn r meth)))
                                                   expr) (getCallers meth)
                         (RtlConst false))).
  End Meth.

  Definition getExternalCallOrder :=
    fold_left (fun rest x => intersect string_dec x (map fst getExternalCalls) :: rest) (map getAllCalls totalOrder) nil.

  Definition computeAllAssigns :=
    concat (map computeRuleAssigns (getRules m))
           ++
           map computeRuleEn (map (@attrName _) (getRules m))
           ++
           concat (map computeMethAssigns (getDefsBodies m))
           ++
           map computeMethRets (getDefsBodies m)
           ++
           map (fun x => computeMethArg (fst x) (arg (snd x))) (getCalls_Sig m)
           ++
           map computeMethEn (getCalls m)
           (*
           map (fun x => computeMethArg (attrName x) (arg (projT1 (attrType x)))) (getDefsBodies m)
           ++
           map computeMethEn (getDefs m)
            *)
           ++
           concat (map computeActionReadIndices (map (@attrName _) (getRules m) ++ getDefs m))
           ++
           concat (map (fun x => computeRegIndexWrite (getRegType x) (attrName x)) (getRegInits m))
           ++
           map (fun x => connectRegWritesToReads (getRegType x) (attrName x)) (getRegInits m).

  Definition computeAllRegInits :=
    map (fun x: Attribute RegInitValue =>
           (attrName x,
            existT ConstT (getRegType x) (getRegInitValue x))) (getRegInits m).

  Definition computeAllRegWrites :=
    map (fun x: Attribute RegInitValue =>
           (attrName x,
            existT RtlExpr (getRegType x)
                   (computeRegFinalWrite (getRegType x) (attrName x)))) (getRegInits m).

  Definition computeAllOutputs :=
    map (fun x => (getMethArg (fst x), arg (snd x))) getExternalCalls
        ++
        map (fun x => (getActionEn (fst x), Bool)) getExternalCalls.

  Definition computeAllInputs :=
    map (fun x => (getActionGuard (fst x), Bool)) getExternalCalls
        ++
        map (fun x => (getMethRet (fst x), ret (snd x))) getExternalCalls.
End UsefulFunctions.

Fixpoint separateRegFiles m :=
  match m with
    | RegFile dataArray read write idxBits data init =>
      ((dataArray, read, write, existT (fun x => ConstT (Vector (snd x) (fst x))) (idxBits, data) init) :: nil, Mod nil nil nil)
    | Mod _ _ _ => (nil, m)
    | ConcatMod m1 m2 =>
      let '(regFiles1, mods1) := separateRegFiles m1 in
      let '(regFiles2, mods2) := separateRegFiles m2 in
      (regFiles1 ++ regFiles2, ConcatMod mods1 mods2)
  end.

Section FinalResult.
  Variable m: Modules.
  Variable totalOrder: list string.
  Variable ignoreLess: list (string * string).

  Definition m' := snd (separateRegFiles m).
  Definition regFs := fst (separateRegFiles m).

  Local Definition checkBypass (r: string * list string * string * sigT (fun x => ConstT (Vector (snd x) (fst x)))) :=
    match r with
      | (data, reads, write, v) =>
        (data, map (fun read =>
                      match head (methPos m totalOrder read) with
                        | None => (read, false)
                        | Some n => match regIndex m totalOrder ignoreLess data n with
                                      | 0 => (read, false)
                                      | _ => (read, true)
                                    end
                      end) reads, write, v)
    end.

  Definition computeModule :=
    {| regFiles := map checkBypass regFs;
       inputs := computeAllInputs m';
       outputs := computeAllOutputs m';
       regInits := computeAllRegInits m';
       regWrites := computeAllRegWrites m' totalOrder ignoreLess;
       wires := computeAllAssigns m' totalOrder ignoreLess|}.
End FinalResult.
