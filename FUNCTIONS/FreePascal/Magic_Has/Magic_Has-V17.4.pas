function Magic_Has(const H, Sig: string): Boolean;
begin
    Magic_Has := (Length(H) >= Length(Sig)) and (Copy(H, 1, Length(Sig)) = Sig);
end;
