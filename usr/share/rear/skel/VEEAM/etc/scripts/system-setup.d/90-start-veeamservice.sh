echo "Starting Veeam agent..."
veeamservice --pidfile /var/run/veeamservice.pid --daemonize || Error "Could not start Veeam agent, check /var/log/veeam/veeamsvc.log"

