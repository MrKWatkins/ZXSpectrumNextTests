# CSpect
&$env:SpectrumEmulatorsPath\CSpect\CSpect.exe $PSScriptRoot\SpritRel.sna

#ZEsarUX
cd $env:SpectrumEmulatorsPath\ZEsarUX\
.\ZEsarUX.exe --noconfigfile --machine tbblue --realvideo --enabletimexvideo --tbblue-fast-boot-mode --sna-no-change-machine --enable-esxdos-handler --nosplash --quickexit $PSScriptRoot\SpritRel.sna
cd $PSScriptRoot
