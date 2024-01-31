local count=0
LogPrint "Verifying PPDM agent service"

while ! systemctl status agentsvc; do
    ((count > 3)) && Error "PPDM agent not running, check agentsvc service"
    let count++
    LogPrint "PPDM agent not running, trying to start (attempt $count)"
    systemctl start agentsvc
    sleep 3
done
