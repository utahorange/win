gpresult /r

# ^somehow parse this properly

Foreach ($gpoitem in Get-ChildItem ".\GPOs") {
    Write-Output "Importing $gpoitem"
    $PSScriptRoot/LGPO.exe /g GPOs\$gpoitem
}
gpupdate /force