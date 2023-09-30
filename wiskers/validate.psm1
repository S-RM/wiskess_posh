function Get-ValidDate ($dateChk, $msg) {
    try {
        $dateChk = [datetime]$dateChk
    }
    catch {
        while(1){
            try{
                $dateChk = [datetime](read-host $msg)
                break
            }
            catch{
                Write-Host 'Not a valid date' -fore red
            }
        }
    }
    return $dateChk.ToString('yyyy-MM-dd')
}
Export-ModuleMember -Function Get-ValidDate