$destinationFolder = "C:\temp"

$url = 'https://download.sysinternals.com/files/PSTools.zip'
invoke-webrequest -Uri $url -outfile $env:temp\pstools.zip
expand-archive -path $env:temp\pstools.zip -destinationpath $env:temp\pstools\
copy-item -path $env:temp\pstools\PsExec.exe -destination $destinationFolder\PsExec.exe