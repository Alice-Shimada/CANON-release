Get[Environment["CANON_TEST_FERMATICA_ENTRY"]];
Clear[Fermatica`FTogether]; Fermatica`FTogether[m_]:=Module[{p},p=StartProcess[Fermatica`$FermatCMD];Export[Environment["CANON_TEST_NATIVE_RECEIPT"],"native_started","Text"];Pause[300];KillProcess[p];$Failed];
